-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Jun 21, 2025 at 09:58 PM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `nec_diagnostics_db`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `get_admin_dashboard_stats` ()   BEGIN
    -- Descripción:
    -- Este procedimiento almacenado recopila estadísticas generales para el dashboard del administrador,
    -- incluyendo el número de estudiantes evaluados, promedio de puntajes, distribución de niveles,
    -- top 5 estudiantes con mejor y peor rendimiento, los últimos 5 estudiantes evaluados,
    -- tests completados por día, y porcentaje de aprobación.
    -- 
    -- Parámetros:
    -- Ninguno (puede expandirse con filtros como fecha si se requiere).
    -- 
    -- Columnas devueltas:
    -- evaluated_students (INT): Número de estudiantes con al menos un test completado.
    -- average_score (INT): Promedio 
-- consulta CALL get_user_diagnostic_stats(x); agregar el id del estudiante de puntajes de todos los tests completados, redondeado al entero más cercano.
    -- level_distribution (TEXT): Cadena JSON con la distribución de estudiantes por nivel (únicos, último nivel).
    -- top_performers (TEXT): Cadena JSON con los 5 estudiantes de mejor rendimiento (nombre, apellido, puntaje).
    -- low_performers (TEXT): Cadena JSON con los 5 estudiantes de menor rendimiento (nombre, apellido, puntaje).
    -- latest_evaluated (TEXT): Cadena JSON con los 5 estudiantes más recientemente evaluados (nombre, apellido, fecha, nivel, puntaje).
    -- tests_by_day (TEXT): Cadena JSON con el número de tests completados por día (últimos 7 días).
    -- approval_rate (INT): Porcentaje de tests aprobados (test_passed = 1), redondeado al entero más cercano.
    -- 
    -- Notas:
    -- Requiere las tablas 'users', 'tests', 'level_history', 'mcer_level', 'test_details', 'questions', y 'toeic_sections'.
    -- El rendimiento se basa en el puntaje del último test completado.
    -- Si no hay datos, algunas columnas devolverán NULL o un array JSON vacío.
    -- average_score y approval_rate se redondean a enteros según solicitud.

    DECLARE v_evaluated_students INT;
    DECLARE v_average_score INT;
    DECLARE v_level_distribution TEXT;
    DECLARE v_top_performers TEXT;
    DECLARE v_low_performers TEXT;
    DECLARE v_latest_evaluated TEXT;
    DECLARE v_tests_by_day TEXT;
    DECLARE v_approval_rate INT;

    -- Número de estudiantes evaluados (con al menos un test completado)
    SELECT COUNT(DISTINCT t.user_fk)
    INTO v_evaluated_students
    FROM tests t
    WHERE t.status = 'COMPLETED';

    -- Promedio de puntajes (redondeado al entero más cercano)
    SELECT ROUND(AVG(t.test_points), 0)
    INTO v_average_score
    FROM tests t
    WHERE t.status = 'COMPLETED';

    -- Distribución de niveles (cadena JSON con conteo por nivel, únicos con último nivel basado en tests)
SELECT CONCAT('[', GROUP_CONCAT(
    CONCAT('{',
        '"level": "', COALESCE(ml.level_name, 'N/A'), '", ',
        '"count": ', student_count
    , '}')
), ']')
INTO v_level_distribution
FROM (
    SELECT COALESCE(t.level_fk, 0) AS level_fk, COUNT(DISTINCT t.user_fk) AS student_count
    FROM tests t
    WHERE t.status = 'COMPLETED'
    AND t.created_at = (
        SELECT MAX(t2.created_at)
        FROM tests t2
        WHERE t2.user_fk = t.user_fk
        AND t2.status = 'COMPLETED'
    )
    GROUP BY COALESCE(t.level_fk, 0)
) AS levels
LEFT JOIN mcer_level ml ON ml.pk_level = levels.level_fk;

    -- Top 5 estudiantes con mejor rendimiento (cadena JSON)
SELECT CONCAT('[', GROUP_CONCAT(
    CONCAT('{',
        '"user_name": "', u.user_name, '", ',
        '"user_lastname": "', u.user_lastname, '", ',
        '"score": ', COALESCE(top_tests.score, 0)
    , '}')
), ']')
INTO v_top_performers
FROM (
    SELECT t.user_fk, t.test_points AS score
    FROM tests t
    WHERE t.status = 'COMPLETED'
    AND t.created_at = (
        SELECT MAX(t2.created_at)
        FROM tests t2
        WHERE t2.user_fk = t.user_fk
        AND t2.status = 'COMPLETED'
    )
    ORDER BY t.test_points DESC
    LIMIT 5
) top_tests
JOIN users u ON u.pk_user = top_tests.user_fk;

    -- Top 5 estudiantes con bajo rendimiento (cadena JSON)
SELECT CONCAT('[', GROUP_CONCAT(
    CONCAT('{',
        '"user_name": "', u.user_name, '", ',
        '"user_lastname": "', u.user_lastname, '", ',
        '"score": ', COALESCE(low_tests.score, 0)
    , '}')
), ']')
INTO v_low_performers
FROM (
    SELECT t.user_fk, t.test_points AS score
    FROM tests t
    WHERE t.status = 'COMPLETED'
    AND t.created_at = (
        SELECT MAX(t2.created_at)
        FROM tests t2
        WHERE t2.user_fk = t.user_fk
        AND t2.status = 'COMPLETED'
    )
    ORDER BY t.test_points ASC
    LIMIT 5
) low_tests
JOIN users u ON u.pk_user = low_tests.user_fk;

    -- Últimos 5 estudiantes evaluados (cadena JSON con fecha, nivel y puntaje)
SELECT CONCAT('[', GROUP_CONCAT(
    CONCAT('{',
        '"user_name": "', u.user_name, '", ',
        '"user_lastname": "', u.user_lastname, '", ',
        '"date": "', DATE_FORMAT(latest_tests.eval_date, '%Y-%m-%d'), '", ',
        '"level": "', COALESCE(ml.level_name, 'N/A'), '", ',
        '"score": ', COALESCE(latest_tests.score, 0)
    , '}')
), ']')
INTO v_latest_evaluated
FROM (
    SELECT t.user_fk, t.created_at AS eval_date, t.test_points AS score, t.level_fk
    FROM tests t
    WHERE t.status = 'COMPLETED'
    ORDER BY t.created_at DESC
    LIMIT 5
) latest_tests
JOIN users u ON u.pk_user = latest_tests.user_fk
LEFT JOIN mcer_level ml ON ml.pk_level = latest_tests.level_fk;

    -- Tests completados por día (últimos 7 días, cadena JSON)
    SELECT CONCAT('[', GROUP_CONCAT(
        CONCAT('{',
            '"date": "', DATE_FORMAT(test_date, '%d %m %Y'), '", ',
            '"count": ', test_count
        , '}')
    ), ']')
    INTO v_tests_by_day
    FROM (
        SELECT DATE(t.created_at) AS test_date, COUNT(*) AS test_count
        FROM tests t
        WHERE t.status = 'COMPLETED'
        AND t.created_at >= DATE_SUB(CURRENT_DATE, INTERVAL 7 DAY)
        GROUP BY DATE(t.created_at)
    ) dt;

    -- Porcentaje de aprobación (redondeado al entero más cercano)
    SELECT ROUND(
        (CAST(COUNT(CASE WHEN t.test_passed = 1 THEN 1 END) AS DECIMAL) / 
        COUNT(*) * 100), 0)
    INTO v_approval_rate
    FROM tests t
    WHERE t.status = 'COMPLETED';

    -- Devolver los resultados
    SELECT 
        v_evaluated_students AS evaluated_students,
        v_average_score AS average_score,
        v_level_distribution AS level_distribution,
        v_top_performers AS top_performers,
        v_low_performers AS low_performers,
        v_latest_evaluated AS latest_evaluated,
        v_tests_by_day AS tests_by_day,
        v_approval_rate AS approval_rate;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_user_diagnostic_stats` (IN `p_user_id` INT)   BEGIN
    -- Descripción:
    -- Este procedimiento almacenado se utiliza para obtener los datos estadísticos y de progreso de un estudiante
    -- específico, destinados a ser mostrados en el dashboard de la aplicación. Recupera información como el nombre,
    -- apellido, nivel de inglés actual, puntaje del último test, número de tests completados, posición en el ranking,
    -- historial de los últimos 5 tests (con puntajes y fechas), así como recomendaciones, fortalezas y debilidades
    -- basadas en el último test completado.
    -- 
    -- Parámetros:
    -- @p_user_id (INT): El identificador único del usuario (estudiante) cuya información se desea consultar.
    -- 
    -- Columnas devueltas:
    -- user_id (INT): Identificador único del estudiante.
    -- user_name (VARCHAR): Nombre del estudiante.
    -- user_lastname (VARCHAR): Apellido del estudiante.
    -- english_level (VARCHAR): Nivel de inglés actual (ej. A1, B1).
    -- last_test_id (INT): Identificador del último test completado.
    -- last_test_score (INT): Puntaje obtenido en el último test.
    -- last_test_date (DATETIME): Fecha y hora del último test.
    -- tests_completed (INT): Número total de tests completados por el estudiante.
    -- rank_position (INT): Posición del estudiante en el ranking basado en el puntaje del último test.
    -- last_5_tests (TEXT): Cadena JSON con los puntajes y fechas de los últimos 5 tests (ordenados del más reciente al más antiguo).
    -- recommendations (TEXT): Lista de recomendaciones basada en el último test, separada por comas.
    -- strengths (TEXT): Lista de fortalezas identificadas en el último test, separada por comas.
    -- weaknesses (TEXT): Lista de debilidades identificadas en el último test, separada por comas.
    -- 
    -- Notas:
    -- - Requiere que las tablas 'users', 'level_history', 'mcer_level', 'tests', 'recommendations', 'strengths',
    --   y 'weaknesses' existan con las columnas correspondientes.
    -- - El ranking se calcula comparando el puntaje del último test con el de otros usuarios.
    -- - Si no hay datos (por ejemplo, ningún test completado), algunas columnas pueden devolver NULL.

    DECLARE v_user_name VARCHAR(100);
    DECLARE v_user_lastname VARCHAR(100);
    DECLARE v_english_level VARCHAR(50);
    DECLARE v_last_test_id INT;
    DECLARE v_last_test_score INT;
    DECLARE v_last_test_date DATETIME;
    DECLARE v_tests_completed INT;
    DECLARE v_rank_position INT;
    DECLARE v_last_5_tests TEXT;
    DECLARE v_recommendations TEXT;
    DECLARE v_strengths TEXT;
    DECLARE v_weaknesses TEXT;

    -- Obtener información básica del usuario y nivel
    SELECT u.user_name, u.user_lastname, ml.level_name
    INTO v_user_name, v_user_lastname, v_english_level
    FROM users u
    JOIN level_history lh ON lh.user_fk = u.pk_user
    JOIN mcer_level ml ON ml.pk_level = lh.level_fk
    WHERE u.pk_user = p_user_id
    AND lh.created_at = (
        SELECT MAX(created_at)
        FROM level_history lh2
        WHERE lh2.user_fk = u.pk_user
    );

    -- Obtener datos del último test
    SELECT t.pk_test, t.test_points, t.created_at
    INTO v_last_test_id, v_last_test_score, v_last_test_date
    FROM tests t
    WHERE t.user_fk = p_user_id
    AND t.status = 'COMPLETED'
    AND t.created_at = (
        SELECT MAX(created_at)
        FROM tests t2
        WHERE t2.user_fk = t.user_fk AND t2.status = 'COMPLETED'
    );

    -- Obtener número de tests completados
    SELECT COUNT(*)
    INTO v_tests_completed
    FROM tests
    WHERE user_fk = p_user_id AND status = 'COMPLETED';

    -- Obtener posición en el ranking
    SELECT COUNT(*) + 1
    INTO v_rank_position
    FROM (
        SELECT t2.user_fk, MAX(t2.created_at) AS max_date
        FROM tests t2
        WHERE t2.status = 'COMPLETED'
        GROUP BY t2.user_fk
    ) latest
    JOIN tests t3 ON t3.user_fk = latest.user_fk AND t3.created_at = latest.max_date
    WHERE t3.test_points > (
        SELECT test_points
        FROM tests t
        WHERE t.user_fk = p_user_id
        AND t.status = 'COMPLETED'
        AND t.created_at = (
            SELECT MAX(created_at)
            FROM tests t2
            WHERE t2.user_fk = t.user_fk AND t2.status = 'COMPLETED'
        )
    );

    -- Obtener los últimos 5 tests
    SELECT CONCAT('[', GROUP_CONCAT(
        CONCAT('{',
            '"score": ', test_points, ', ',
            '"date": "', DATE_FORMAT(created_at, '%d %m %Y'), '"'
        , '}')
    ), ']')
    INTO v_last_5_tests
    FROM (
        SELECT test_points, created_at
        FROM tests
        WHERE user_fk = p_user_id AND status = 'COMPLETED'
        ORDER BY created_at DESC
        LIMIT 5
    ) t;

    -- Obtener recomendaciones, fortalezas y debilidades (usando v_last_test_id)
    SELECT GROUP_CONCAT(recommendation_text SEPARATOR ', ')
    INTO v_recommendations
    FROM recommendations
    WHERE test_fk = v_last_test_id;

    SELECT GROUP_CONCAT(strength_text SEPARATOR ', ')
    INTO v_strengths
    FROM strengths
    WHERE test_fk = v_last_test_id;

    SELECT GROUP_CONCAT(weakness_text SEPARATOR ', ')
    INTO v_weaknesses
    FROM weaknesses
    WHERE test_fk = v_last_test_id;

    -- Devolver los resultados
    SELECT 
        p_user_id AS user_id,
        v_user_name AS user_name,
        v_user_lastname AS user_lastname,
        v_english_level AS english_level,
        v_last_test_id AS last_test_id,
        v_last_test_score AS last_test_score,
        v_last_test_date AS last_test_date,
        v_tests_completed AS tests_completed,
        v_rank_position AS rank_position,
        v_last_5_tests AS last_5_tests,
        v_recommendations AS recommendations,
        v_strengths AS strengths,
        v_weaknesses AS weaknesses;

END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `answers`
--

CREATE TABLE `answers` (
  `pk_answer` int(11) NOT NULL,
  `question_fk` int(11) NOT NULL,
  `answer_text` text DEFAULT NULL,
  `is_correct` tinyint(1) DEFAULT NULL,
  `status` varchar(10) NOT NULL DEFAULT 'ACTIVE',
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `answers`
--

INSERT INTO `answers` (`pk_answer`, `question_fk`, `answer_text`, `is_correct`, `status`, `created_at`, `updated_at`) VALUES
(1, 1, 'To accuse', 0, 'ACTIVE', '2025-04-19 15:31:40', '2025-04-19 15:31:40'),
(2, 1, 'To inform', 0, 'ACTIVE', '2025-04-19 15:31:40', '2025-04-19 15:31:40'),
(3, 1, 'To make a request', 0, 'ACTIVE', '2025-04-19 15:31:40', '2025-04-19 15:31:40'),
(4, 1, 'To praise', 1, 'ACTIVE', '2025-04-19 15:31:40', '2025-04-19 15:31:40'),
(5, 2, 'All the delegates were staff from the same office.', 0, 'ACTIVE', '2025-04-19 15:36:01', '2025-04-19 15:36:01'),
(6, 2, 'It included several talks.', 0, 'ACTIVE', '2025-04-19 15:36:01', '2025-04-19 15:36:01'),
(7, 2, 'It lasted one day.', 1, 'ACTIVE', '2025-04-19 15:36:01', '2025-04-19 15:36:01'),
(8, 2, 'Motivation was the only topic discussed.', 0, 'ACTIVE', '2025-04-19 15:36:01', '2025-04-19 15:36:01'),
(9, 3, 'He works in the same office as Anne.', 0, 'ACTIVE', '2025-04-19 15:40:18', '2025-04-19 15:40:18'),
(10, 3, 'He has a very busy schedule.', 1, 'ACTIVE', '2025-04-19 15:40:18', '2025-04-19 15:40:18'),
(11, 3, 'He is a leading expert on staff motivation.', 0, 'ACTIVE', '2025-04-19 15:40:18', '2025-04-19 15:40:18'),
(12, 3, 'Anne knows him better than Helen does.', 0, 'ACTIVE', '2025-04-19 15:40:18', '2025-04-19 15:40:18'),
(13, 4, 'Anne has lost it.', 1, 'ACTIVE', '2025-04-19 15:42:28', '2025-04-19 15:42:28'),
(14, 4, 'Anne has found it.', 0, 'ACTIVE', '2025-04-19 15:42:28', '2025-04-19 15:42:28'),
(15, 4, 'Anne has sent it to Helen.', 0, 'ACTIVE', '2025-04-19 15:42:28', '2025-04-19 15:42:28'),
(16, 4, 'Anne has completed it.', 0, 'ACTIVE', '2025-04-19 15:42:28', '2025-04-19 15:42:28'),
(17, 5, 'delivering', 0, 'ACTIVE', '2025-04-19 16:38:27', '2025-04-19 16:38:27'),
(18, 5, 'to deliver', 0, 'ACTIVE', '2025-04-19 16:38:27', '2025-04-19 16:38:27'),
(19, 5, 'to be deliver', 0, 'ACTIVE', '2025-04-19 16:38:27', '2025-04-19 16:38:27'),
(20, 5, 'delivered', 1, 'ACTIVE', '2025-04-19 16:38:27', '2025-04-19 16:38:27'),
(21, 6, 'delivering', 0, 'ACTIVE', '2025-04-19 16:55:24', '2025-04-19 16:55:24'),
(22, 6, 'to deliver', 0, 'ACTIVE', '2025-04-19 16:55:24', '2025-04-19 16:55:24'),
(23, 6, 'to be deliver', 0, 'ACTIVE', '2025-04-19 16:55:24', '2025-04-19 16:55:24'),
(24, 6, 'delivered', 1, 'ACTIVE', '2025-04-19 16:55:24', '2025-04-19 16:55:24'),
(25, 7, 'since', 0, 'ACTIVE', '2025-04-19 16:55:24', '2025-04-19 16:55:24'),
(26, 7, 'for', 1, 'ACTIVE', '2025-04-19 16:55:24', '2025-04-19 16:55:24'),
(27, 7, 'during', 0, 'ACTIVE', '2025-04-19 16:55:24', '2025-04-19 16:55:24'),
(28, 7, 'while', 0, 'ACTIVE', '2025-04-19 16:55:24', '2025-04-19 16:55:24'),
(29, 8, 'was eating', 1, 'ACTIVE', '2025-04-19 16:55:24', '2025-04-19 16:55:24'),
(30, 8, 'eating', 0, 'ACTIVE', '2025-04-19 16:55:24', '2025-04-19 16:55:24'),
(31, 8, 'ate', 0, 'ACTIVE', '2025-04-19 16:55:24', '2025-04-19 16:55:24'),
(32, 8, 'was eat', 0, 'ACTIVE', '2025-04-19 16:55:24', '2025-04-19 16:55:24'),
(33, 1, 'deliveringgggg', 0, 'INACTIVE', '2025-04-20 12:01:11', '2025-04-20 12:30:37'),
(34, 1, 'Nueva respuesta modificada', 1, 'INACTIVE', '2025-04-20 12:01:22', '2025-04-20 12:30:55'),
(35, 1, 'Nueva respuesta modificada a question 2', 1, 'INACTIVE', '2025-04-20 12:01:59', '2025-04-20 12:29:26'),
(36, 1, 'hh', 0, 'INACTIVE', '2025-04-20 12:04:36', '2025-04-20 12:31:14'),
(37, 1, 'test', 0, 'INACTIVE', '2025-04-20 12:05:09', '2025-04-20 12:31:20'),
(38, 1, 'Opción A test', 1, 'INACTIVE', '2025-04-20 12:13:34', '2025-04-20 12:31:23'),
(39, 1, 'Opción B test', 0, 'INACTIVE', '2025-04-20 12:13:34', '2025-04-20 12:31:26'),
(40, 1, 'Opción A test', 1, 'INACTIVE', '2025-04-20 12:14:06', '2025-04-20 12:31:29'),
(41, 1, 'Opción B test', 0, 'INACTIVE', '2025-04-20 12:14:06', '2025-04-20 12:51:39'),
(42, 9, 'Large', 1, 'ACTIVE', '2025-05-01 15:18:09', '2025-05-01 15:18:09'),
(43, 9, 'Medium', 0, 'ACTIVE', '2025-05-01 15:18:09', '2025-05-01 15:18:09'),
(44, 9, 'Small', 0, 'ACTIVE', '2025-05-01 15:18:09', '2025-05-01 15:18:09'),
(45, 9, 'Extra large', 0, 'ACTIVE', '2025-05-01 15:18:09', '2025-05-01 15:18:09'),
(46, 10, 'Black', 1, 'ACTIVE', '2025-05-01 15:18:09', '2025-05-01 15:18:09'),
(47, 10, 'With cream and sugar', 0, 'ACTIVE', '2025-05-01 15:18:09', '2025-05-01 15:18:09'),
(48, 10, 'With milk only', 0, 'ACTIVE', '2025-05-01 15:18:09', '2025-05-01 15:18:09'),
(49, 10, 'With sugar only', 0, 'ACTIVE', '2025-05-01 15:18:09', '2025-05-01 15:18:09'),
(50, 11, 'In a coffee shop', 1, 'ACTIVE', '2025-05-01 15:18:09', '2025-05-01 15:18:09'),
(51, 11, 'In an office', 0, 'ACTIVE', '2025-05-01 15:18:09', '2025-05-01 15:18:09'),
(52, 11, 'At home', 0, 'ACTIVE', '2025-05-01 15:18:09', '2025-05-01 15:18:09'),
(53, 11, 'In a supermarket', 0, 'ACTIVE', '2025-05-01 15:18:09', '2025-05-01 15:18:09'),
(54, 12, 'Cream or sugar', 1, 'ACTIVE', '2025-05-01 15:18:09', '2025-05-01 15:18:09'),
(55, 12, 'A pastry', 0, 'ACTIVE', '2025-05-01 15:18:09', '2025-05-01 15:18:09'),
(56, 12, 'A discount', 0, 'ACTIVE', '2025-05-01 15:18:09', '2025-05-01 15:18:09'),
(57, 12, 'A different size', 0, 'ACTIVE', '2025-05-01 15:18:09', '2025-05-01 15:18:09'),
(58, 13, 'Sent it yesterday', 1, 'ACTIVE', '2025-05-01 15:18:36', '2025-05-01 15:18:36'),
(59, 13, 'Forgot to send it', 0, 'ACTIVE', '2025-05-01 15:18:36', '2025-05-01 15:18:36'),
(60, 13, 'Will send it today', 0, 'ACTIVE', '2025-05-01 15:18:36', '2025-05-01 15:18:36'),
(61, 13, 'Needs to review it first', 0, 'ACTIVE', '2025-05-01 15:18:36', '2025-05-01 15:18:36'),
(62, 14, 'Today', 1, 'ACTIVE', '2025-05-01 15:18:36', '2025-05-01 15:18:36'),
(63, 14, 'Tomorrow', 0, 'ACTIVE', '2025-05-01 15:18:36', '2025-05-01 15:18:36'),
(64, 14, 'Next week', 0, 'ACTIVE', '2025-05-01 15:18:36', '2025-05-01 15:18:36'),
(65, 14, 'Yesterday', 0, 'ACTIVE', '2025-05-01 15:18:36', '2025-05-01 15:18:36'),
(66, 15, 'In an office', 1, 'ACTIVE', '2025-05-01 15:18:36', '2025-05-01 15:18:36'),
(67, 15, 'At a restaurant', 0, 'ACTIVE', '2025-05-01 15:18:36', '2025-05-01 15:18:36'),
(68, 15, 'In a store', 0, 'ACTIVE', '2025-05-01 15:18:36', '2025-05-01 15:18:36'),
(69, 15, 'At a school', 0, 'ACTIVE', '2025-05-01 15:18:36', '2025-05-01 15:18:36'),
(70, 16, 'For today\'s meeting', 1, 'ACTIVE', '2025-05-01 15:18:36', '2025-05-01 15:18:36'),
(71, 16, 'For a client presentation', 0, 'ACTIVE', '2025-05-01 15:18:36', '2025-05-01 15:18:36'),
(72, 16, 'For annual review', 0, 'ACTIVE', '2025-05-01 15:18:36', '2025-05-01 15:18:36'),
(73, 16, 'For training purposes', 0, 'ACTIVE', '2025-05-01 15:18:36', '2025-05-01 15:18:36'),
(74, 17, 'Cheeseburger and fries', 1, 'ACTIVE', '2025-05-01 15:18:51', '2025-05-01 15:18:51'),
(75, 17, 'Pizza and salad', 0, 'ACTIVE', '2025-05-01 15:18:51', '2025-05-01 15:18:51'),
(76, 17, 'Chicken sandwich', 0, 'ACTIVE', '2025-05-01 15:18:51', '2025-05-01 15:18:51'),
(77, 17, 'Hot dog', 0, 'ACTIVE', '2025-05-01 15:18:51', '2025-05-01 15:18:51'),
(78, 18, 'Soda', 1, 'ACTIVE', '2025-05-01 15:18:51', '2025-05-01 15:18:51'),
(79, 18, 'Water', 0, 'ACTIVE', '2025-05-01 15:18:51', '2025-05-01 15:18:51'),
(80, 18, 'Coffee', 0, 'ACTIVE', '2025-05-01 15:18:51', '2025-05-01 15:18:51'),
(81, 18, 'Juice', 0, 'ACTIVE', '2025-05-01 15:18:51', '2025-05-01 15:18:51'),
(82, 19, 'At a restaurant', 1, 'ACTIVE', '2025-05-01 15:18:51', '2025-05-01 15:18:51'),
(83, 19, 'At a grocery store', 0, 'ACTIVE', '2025-05-01 15:18:51', '2025-05-01 15:18:51'),
(84, 19, 'At home', 0, 'ACTIVE', '2025-05-01 15:18:51', '2025-05-01 15:18:51'),
(85, 19, 'At a coffee shop', 0, 'ACTIVE', '2025-05-01 15:18:51', '2025-05-01 15:18:51'),
(86, 20, 'If they want a drink', 1, 'ACTIVE', '2025-05-01 15:18:51', '2025-05-01 15:18:51'),
(87, 20, 'If they want dessert', 0, 'ACTIVE', '2025-05-01 15:18:51', '2025-05-01 15:18:51'),
(88, 20, 'If they need a menu', 0, 'ACTIVE', '2025-05-01 15:18:51', '2025-05-01 15:18:51'),
(89, 20, 'If they want to pay now', 0, 'ACTIVE', '2025-05-01 15:18:51', '2025-05-01 15:18:51'),
(90, 21, 'Sore throat and fever', 1, 'ACTIVE', '2025-05-01 15:19:13', '2025-05-01 15:19:13'),
(91, 21, 'Headache and cough', 0, 'ACTIVE', '2025-05-01 15:19:13', '2025-05-01 15:19:13'),
(92, 21, 'Stomach pain', 0, 'ACTIVE', '2025-05-01 15:19:13', '2025-05-01 15:19:13'),
(93, 21, 'Rash', 0, 'ACTIVE', '2025-05-01 15:19:13', '2025-05-01 15:19:13'),
(94, 22, 'A doctor', 1, 'ACTIVE', '2025-05-01 15:19:13', '2025-05-01 15:19:13'),
(95, 22, 'A nurse', 0, 'ACTIVE', '2025-05-01 15:19:13', '2025-05-01 15:19:13'),
(96, 22, 'A receptionist', 0, 'ACTIVE', '2025-05-01 15:19:13', '2025-05-01 15:19:13'),
(97, 22, 'A pharmacist', 0, 'ACTIVE', '2025-05-01 15:19:13', '2025-05-01 15:19:13'),
(98, 23, 'In a doctor\'s office', 1, 'ACTIVE', '2025-05-01 15:19:13', '2025-05-01 15:19:13'),
(99, 23, 'In a hospital room', 0, 'ACTIVE', '2025-05-01 15:19:13', '2025-05-01 15:19:13'),
(100, 23, 'At a pharmacy', 0, 'ACTIVE', '2025-05-01 15:19:13', '2025-05-01 15:19:13'),
(101, 23, 'At home', 0, 'ACTIVE', '2025-05-01 15:19:13', '2025-05-01 15:19:13'),
(102, 24, 'Take a look', 1, 'ACTIVE', '2025-05-01 15:19:13', '2025-05-01 15:19:13'),
(103, 24, 'Prescribe medicine', 0, 'ACTIVE', '2025-05-01 15:19:13', '2025-05-01 15:19:13'),
(104, 24, 'Call a specialist', 0, 'ACTIVE', '2025-05-01 15:19:13', '2025-05-01 15:19:13'),
(105, 24, 'Schedule a test', 0, 'ACTIVE', '2025-05-01 15:19:13', '2025-05-01 15:19:13'),
(106, 25, 'Spain', 1, 'ACTIVE', '2025-05-01 15:19:30', '2025-05-01 15:19:30'),
(107, 25, 'France', 0, 'ACTIVE', '2025-05-01 15:19:30', '2025-05-01 15:19:30'),
(108, 25, 'Italy', 0, 'ACTIVE', '2025-05-01 15:19:30', '2025-05-01 15:19:30'),
(109, 25, 'Germany', 0, 'ACTIVE', '2025-05-01 15:19:30', '2025-05-01 15:19:30'),
(110, 26, 'This summer', 1, 'ACTIVE', '2025-05-01 15:19:30', '2025-05-01 15:19:30'),
(111, 26, 'Next winter', 0, 'ACTIVE', '2025-05-01 15:19:30', '2025-05-01 15:19:30'),
(112, 26, 'This weekend', 0, 'ACTIVE', '2025-05-01 15:19:30', '2025-05-01 15:19:30'),
(113, 26, 'Next year', 0, 'ACTIVE', '2025-05-01 15:19:30', '2025-05-01 15:19:30'),
(114, 27, 'Excited', 1, 'ACTIVE', '2025-05-01 15:19:30', '2025-05-01 15:19:30'),
(115, 27, 'Concerned', 0, 'ACTIVE', '2025-05-01 15:19:30', '2025-05-01 15:19:30'),
(116, 27, 'Disappointed', 0, 'ACTIVE', '2025-05-01 15:19:30', '2025-05-01 15:19:30'),
(117, 27, 'Confused', 0, 'ACTIVE', '2025-05-01 15:19:30', '2025-05-01 15:19:30'),
(118, 28, 'Summer travel plans', 1, 'ACTIVE', '2025-05-01 15:19:30', '2025-05-01 15:19:30'),
(119, 28, 'Work schedule', 0, 'ACTIVE', '2025-05-01 15:19:30', '2025-05-01 15:19:30'),
(120, 28, 'Family visit', 0, 'ACTIVE', '2025-05-01 15:19:30', '2025-05-01 15:19:30'),
(121, 28, 'School vacation', 0, 'ACTIVE', '2025-05-01 15:19:30', '2025-05-01 15:19:30'),
(122, 29, 'John from HR', 1, 'ACTIVE', '2025-05-01 15:23:10', '2025-05-01 15:23:10'),
(123, 29, 'Anna from Sales', 0, 'ACTIVE', '2025-05-01 15:23:10', '2025-05-01 15:23:10'),
(124, 29, 'The hotel manager', 0, 'ACTIVE', '2025-05-01 15:23:10', '2025-05-01 15:23:10'),
(125, 29, 'A customer service representative', 0, 'ACTIVE', '2025-05-01 15:23:10', '2025-05-01 15:23:10'),
(126, 30, 'HR', 1, 'ACTIVE', '2025-05-01 15:23:10', '2025-05-01 15:23:10'),
(127, 30, 'Sales', 0, 'ACTIVE', '2025-05-01 15:23:10', '2025-05-01 15:23:10'),
(128, 30, 'Marketing', 0, 'ACTIVE', '2025-05-01 15:23:10', '2025-05-01 15:23:10'),
(129, 30, 'IT', 0, 'ACTIVE', '2025-05-01 15:23:10', '2025-05-01 15:23:10'),
(130, 31, 'She says \"Yes, speaking\"', 1, 'ACTIVE', '2025-05-01 15:23:10', '2025-05-01 15:23:10'),
(131, 31, 'She says \"Hello, this is Anna\"', 0, 'ACTIVE', '2025-05-01 15:23:10', '2025-05-01 15:23:10'),
(132, 31, 'She asks \"Who is calling?\"', 0, 'ACTIVE', '2025-05-01 15:23:10', '2025-05-01 15:23:10'),
(133, 31, 'She says \"Please hold\"', 0, 'ACTIVE', '2025-05-01 15:23:10', '2025-05-01 15:23:10'),
(134, 32, 'It is not specified in the conversation', 1, 'ACTIVE', '2025-05-01 15:23:10', '2025-05-01 15:23:10'),
(135, 32, 'To schedule a meeting', 0, 'ACTIVE', '2025-05-01 15:23:10', '2025-05-01 15:23:10'),
(136, 32, 'To discuss a job offer', 0, 'ACTIVE', '2025-05-01 15:23:10', '2025-05-01 15:23:10'),
(137, 32, 'To confirm an appointment', 0, 'ACTIVE', '2025-05-01 15:23:10', '2025-05-01 15:23:10'),
(138, 33, 'A double room', 1, 'ACTIVE', '2025-05-01 15:23:21', '2025-05-01 15:23:21'),
(139, 33, 'A single room', 0, 'ACTIVE', '2025-05-01 15:23:21', '2025-05-01 15:23:21'),
(140, 33, 'A suite', 0, 'ACTIVE', '2025-05-01 15:23:21', '2025-05-01 15:23:21'),
(141, 33, 'A twin room', 0, 'ACTIVE', '2025-05-01 15:23:21', '2025-05-01 15:23:21'),
(142, 34, 'Two nights', 1, 'ACTIVE', '2025-05-01 15:23:21', '2025-05-01 15:23:21'),
(143, 34, 'One night', 0, 'ACTIVE', '2025-05-01 15:23:21', '2025-05-01 15:23:21'),
(144, 34, 'Three nights', 0, 'ACTIVE', '2025-05-01 15:23:21', '2025-05-01 15:23:21'),
(145, 34, 'A week', 0, 'ACTIVE', '2025-05-01 15:23:21', '2025-05-01 15:23:21'),
(146, 35, 'Room preference', 1, 'ACTIVE', '2025-05-01 15:23:21', '2025-05-01 15:23:21'),
(147, 35, 'Payment method', 0, 'ACTIVE', '2025-05-01 15:23:21', '2025-05-01 15:23:21'),
(148, 35, 'Check-in time', 0, 'ACTIVE', '2025-05-01 15:23:21', '2025-05-01 15:23:21'),
(149, 35, 'Special requests', 0, 'ACTIVE', '2025-05-01 15:23:21', '2025-05-01 15:23:21'),
(150, 36, 'Making a reservation', 1, 'ACTIVE', '2025-05-01 15:23:21', '2025-05-01 15:23:21'),
(151, 36, 'Checking in', 0, 'ACTIVE', '2025-05-01 15:23:21', '2025-05-01 15:23:21'),
(152, 36, 'Complaining about service', 0, 'ACTIVE', '2025-05-01 15:23:21', '2025-05-01 15:23:21'),
(153, 36, 'Asking for directions', 0, 'ACTIVE', '2025-05-01 15:23:21', '2025-05-01 15:23:21'),
(154, 37, 'Four', 1, 'ACTIVE', '2025-05-01 15:23:33', '2025-05-01 15:23:33'),
(155, 37, 'Two', 0, 'ACTIVE', '2025-05-01 15:23:33', '2025-05-01 15:23:33'),
(156, 37, 'Six', 0, 'ACTIVE', '2025-05-01 15:23:33', '2025-05-01 15:23:33'),
(157, 37, 'Eight', 0, 'ACTIVE', '2025-05-01 15:23:33', '2025-05-01 15:23:33'),
(158, 38, '7 PM', 1, 'ACTIVE', '2025-05-01 15:23:33', '2025-05-01 15:23:33'),
(159, 38, '6 PM', 0, 'ACTIVE', '2025-05-01 15:23:33', '2025-05-01 15:23:33'),
(160, 38, '8 PM', 0, 'ACTIVE', '2025-05-01 15:23:33', '2025-05-01 15:23:33'),
(161, 38, '7:30 PM', 0, 'ACTIVE', '2025-05-01 15:23:33', '2025-05-01 15:23:33'),
(162, 39, 'The preferred time', 1, 'ACTIVE', '2025-05-01 15:23:33', '2025-05-01 15:23:33'),
(163, 39, 'The menu preference', 0, 'ACTIVE', '2025-05-01 15:23:33', '2025-05-01 15:23:33'),
(164, 39, 'The guest\'s name', 0, 'ACTIVE', '2025-05-01 15:23:33', '2025-05-01 15:23:33'),
(165, 39, 'Special dietary requirements', 0, 'ACTIVE', '2025-05-01 15:23:33', '2025-05-01 15:23:33'),
(166, 40, 'Reserving a table', 1, 'ACTIVE', '2025-05-01 15:23:33', '2025-05-01 15:23:33'),
(167, 40, 'Ordering food', 0, 'ACTIVE', '2025-05-01 15:23:33', '2025-05-01 15:23:33'),
(168, 40, 'Complaining about service', 0, 'ACTIVE', '2025-05-01 15:23:33', '2025-05-01 15:23:33'),
(169, 40, 'Asking about the menu', 0, 'ACTIVE', '2025-05-01 15:23:33', '2025-05-01 15:23:33'),
(170, 41, 'The train station', 1, 'ACTIVE', '2025-05-01 15:23:48', '2025-05-01 15:23:48'),
(171, 41, 'The bus station', 0, 'ACTIVE', '2025-05-01 15:23:48', '2025-05-01 15:23:48'),
(172, 41, 'The airport', 0, 'ACTIVE', '2025-05-01 15:23:48', '2025-05-01 15:23:48'),
(173, 41, 'The hotel', 0, 'ACTIVE', '2025-05-01 15:23:48', '2025-05-01 15:23:48'),
(174, 42, 'Go straight and take the second right', 1, 'ACTIVE', '2025-05-01 15:23:49', '2025-05-01 15:23:49'),
(175, 42, 'Turn left at the traffic light', 0, 'ACTIVE', '2025-05-01 15:23:49', '2025-05-01 15:23:49'),
(176, 42, 'Take the first left after the park', 0, 'ACTIVE', '2025-05-01 15:23:49', '2025-05-01 15:23:49'),
(177, 42, 'Go straight for three blocks', 0, 'ACTIVE', '2025-05-01 15:23:49', '2025-05-01 15:23:49'),
(178, 43, 'Thanks a lot', 1, 'ACTIVE', '2025-05-01 15:23:49', '2025-05-01 15:23:49'),
(179, 43, 'Could you repeat that?', 0, 'ACTIVE', '2025-05-01 15:23:49', '2025-05-01 15:23:49'),
(180, 43, 'Is it far?', 0, 'ACTIVE', '2025-05-01 15:23:49', '2025-05-01 15:23:49'),
(181, 43, 'I don\'t understand', 0, 'ACTIVE', '2025-05-01 15:23:49', '2025-05-01 15:23:49'),
(182, 44, 'Strangers', 1, 'ACTIVE', '2025-05-01 15:23:49', '2025-05-01 15:23:49'),
(183, 44, 'Colleagues', 0, 'ACTIVE', '2025-05-01 15:23:49', '2025-05-01 15:23:49'),
(184, 44, 'Friends', 0, 'ACTIVE', '2025-05-01 15:23:49', '2025-05-01 15:23:49'),
(185, 44, 'Family members', 0, 'ACTIVE', '2025-05-01 15:23:49', '2025-05-01 15:23:49'),
(186, 45, 'Project manager', 1, 'ACTIVE', '2025-05-01 15:24:01', '2025-05-01 15:24:01'),
(187, 45, 'Sales representative', 0, 'ACTIVE', '2025-05-01 15:24:01', '2025-05-01 15:24:01'),
(188, 45, 'HR specialist', 0, 'ACTIVE', '2025-05-01 15:24:01', '2025-05-01 15:24:01'),
(189, 45, 'Accountant', 0, 'ACTIVE', '2025-05-01 15:24:01', '2025-05-01 15:24:01'),
(190, 46, 'That\'s impressive', 1, 'ACTIVE', '2025-05-01 15:24:01', '2025-05-01 15:24:01'),
(191, 46, 'I see', 0, 'ACTIVE', '2025-05-01 15:24:01', '2025-05-01 15:24:01'),
(192, 46, 'Interesting', 0, 'ACTIVE', '2025-05-01 15:24:01', '2025-05-01 15:24:01'),
(193, 46, 'Tell me more', 0, 'ACTIVE', '2025-05-01 15:24:01', '2025-05-01 15:24:01'),
(194, 47, 'The candidate\'s previous job', 1, 'ACTIVE', '2025-05-01 15:24:01', '2025-05-01 15:24:01'),
(195, 47, 'The candidate\'s education', 0, 'ACTIVE', '2025-05-01 15:24:01', '2025-05-01 15:24:01'),
(196, 47, 'The candidate\'s skills', 0, 'ACTIVE', '2025-05-01 15:24:01', '2025-05-01 15:24:01'),
(197, 47, 'The candidate\'s availability', 0, 'ACTIVE', '2025-05-01 15:24:01', '2025-05-01 15:24:01'),
(198, 48, 'A job interview', 1, 'ACTIVE', '2025-05-01 15:24:01', '2025-05-01 15:24:01'),
(199, 48, 'A performance review', 0, 'ACTIVE', '2025-05-01 15:24:01', '2025-05-01 15:24:01'),
(200, 48, 'A team meeting', 0, 'ACTIVE', '2025-05-01 15:24:01', '2025-05-01 15:24:01'),
(201, 48, 'A training session', 0, 'ACTIVE', '2025-05-01 15:24:01', '2025-05-01 15:24:01'),
(202, 49, 'It has been raining all day.', 1, 'ACTIVE', '2025-05-01 15:27:47', '2025-05-01 15:27:47'),
(203, 49, 'It is sunny and warm.', 0, 'ACTIVE', '2025-05-01 15:27:47', '2025-05-01 15:27:47'),
(204, 49, 'It is snowing heavily.', 0, 'ACTIVE', '2025-05-01 15:27:47', '2025-05-01 15:27:47'),
(205, 49, 'There is a thunderstorm.', 0, 'ACTIVE', '2025-05-01 15:27:47', '2025-05-01 15:27:47'),
(206, 50, 'They miss the sun.', 1, 'ACTIVE', '2025-05-01 15:27:47', '2025-05-01 15:27:47'),
(207, 50, 'They enjoy the rain.', 0, 'ACTIVE', '2025-05-01 15:27:47', '2025-05-01 15:27:47'),
(208, 50, 'They are scared of the weather.', 0, 'ACTIVE', '2025-05-01 15:27:47', '2025-05-01 15:27:47'),
(209, 50, 'They don\'t care about the weather.', 0, 'ACTIVE', '2025-05-01 15:27:47', '2025-05-01 15:27:47'),
(210, 51, 'Better weather', 1, 'ACTIVE', '2025-05-01 15:27:47', '2025-05-01 15:27:47'),
(211, 51, 'More rain', 0, 'ACTIVE', '2025-05-01 15:27:47', '2025-05-01 15:27:47'),
(212, 51, 'A day off work', 0, 'ACTIVE', '2025-05-01 15:27:47', '2025-05-01 15:27:47'),
(213, 51, 'To go shopping', 0, 'ACTIVE', '2025-05-01 15:27:47', '2025-05-01 15:27:47'),
(214, 52, 'All day', 1, 'ACTIVE', '2025-05-01 15:27:47', '2025-05-01 15:27:47'),
(215, 52, 'For an hour', 0, 'ACTIVE', '2025-05-01 15:27:47', '2025-05-01 15:27:47'),
(216, 52, 'Since yesterday', 0, 'ACTIVE', '2025-05-01 15:27:47', '2025-05-01 15:27:47'),
(217, 52, 'It hasn\'t rained yet', 0, 'ACTIVE', '2025-05-01 15:27:47', '2025-05-01 15:27:47'),
(218, 53, 'Medium', 1, 'ACTIVE', '2025-05-01 15:28:00', '2025-05-01 15:28:00'),
(219, 53, 'Small', 0, 'ACTIVE', '2025-05-01 15:28:00', '2025-05-01 15:28:00'),
(220, 53, 'Large', 0, 'ACTIVE', '2025-05-01 15:28:00', '2025-05-01 15:28:00'),
(221, 53, 'Extra large', 0, 'ACTIVE', '2025-05-01 15:28:00', '2025-05-01 15:28:00'),
(222, 54, 'Checks the back', 1, 'ACTIVE', '2025-05-01 15:28:00', '2025-05-01 15:28:00'),
(223, 54, 'Asks for more money', 0, 'ACTIVE', '2025-05-01 15:28:00', '2025-05-01 15:28:00'),
(224, 54, 'Says they don\'t have it', 0, 'ACTIVE', '2025-05-01 15:28:00', '2025-05-01 15:28:00'),
(225, 54, 'Offers a discount', 0, 'ACTIVE', '2025-05-01 15:28:00', '2025-05-01 15:28:00'),
(226, 55, 'Says \"Thank you\"', 1, 'ACTIVE', '2025-05-01 15:28:00', '2025-05-01 15:28:00'),
(227, 55, 'Asks for another size', 0, 'ACTIVE', '2025-05-01 15:28:00', '2025-05-01 15:28:00'),
(228, 55, 'Complains about the price', 0, 'ACTIVE', '2025-05-01 15:28:00', '2025-05-01 15:28:00'),
(229, 55, 'Leaves the store', 0, 'ACTIVE', '2025-05-01 15:28:00', '2025-05-01 15:28:00'),
(230, 56, 'In a clothing store', 1, 'ACTIVE', '2025-05-01 15:28:00', '2025-05-01 15:28:00'),
(231, 56, 'At a supermarket', 0, 'ACTIVE', '2025-05-01 15:28:00', '2025-05-01 15:28:00'),
(232, 56, 'In a restaurant', 0, 'ACTIVE', '2025-05-01 15:28:00', '2025-05-01 15:28:00'),
(233, 56, 'At a bank', 0, 'ACTIVE', '2025-05-01 15:28:00', '2025-05-01 15:28:00'),
(234, 57, 'Science books', 1, 'ACTIVE', '2025-05-01 15:28:12', '2025-05-01 15:28:12'),
(235, 57, 'History books', 0, 'ACTIVE', '2025-05-01 15:28:12', '2025-05-01 15:28:12'),
(236, 57, 'Magazines', 0, 'ACTIVE', '2025-05-01 15:28:12', '2025-05-01 15:28:12'),
(237, 57, 'Newspapers', 0, 'ACTIVE', '2025-05-01 15:28:12', '2025-05-01 15:28:12'),
(238, 58, 'Aisle 4 on the right', 1, 'ACTIVE', '2025-05-01 15:28:12', '2025-05-01 15:28:12'),
(239, 58, 'Aisle 3 on the left', 0, 'ACTIVE', '2025-05-01 15:28:12', '2025-05-01 15:28:12'),
(240, 58, 'Near the entrance', 0, 'ACTIVE', '2025-05-01 15:28:12', '2025-05-01 15:28:12'),
(241, 58, 'In the basement', 0, 'ACTIVE', '2025-05-01 15:28:12', '2025-05-01 15:28:12'),
(242, 59, 'Says \"Thanks!\"', 1, 'ACTIVE', '2025-05-01 15:28:12', '2025-05-01 15:28:12'),
(243, 59, 'Asks for more help', 0, 'ACTIVE', '2025-05-01 15:28:12', '2025-05-01 15:28:12'),
(244, 59, 'Complains about the location', 0, 'ACTIVE', '2025-05-01 15:28:12', '2025-05-01 15:28:12'),
(245, 59, 'Doesn\'t say anything', 0, 'ACTIVE', '2025-05-01 15:28:12', '2025-05-01 15:28:12'),
(246, 60, 'In a library', 1, 'ACTIVE', '2025-05-01 15:28:12', '2025-05-01 15:28:12'),
(247, 60, 'In a bookstore', 0, 'ACTIVE', '2025-05-01 15:28:12', '2025-05-01 15:28:12'),
(248, 60, 'In a school', 0, 'ACTIVE', '2025-05-01 15:28:12', '2025-05-01 15:28:12'),
(249, 60, 'In an office', 0, 'ACTIVE', '2025-05-01 15:28:12', '2025-05-01 15:28:12'),
(250, 61, 'To request a meeting', 1, 'ACTIVE', '2025-05-01 15:28:28', '2025-05-01 15:28:28'),
(251, 61, 'To submit a report', 0, 'ACTIVE', '2025-05-01 15:28:28', '2025-05-01 15:28:28'),
(252, 61, 'To ask for a promotion', 0, 'ACTIVE', '2025-05-01 15:28:28', '2025-05-01 15:28:28'),
(253, 61, 'To complain about a coworker', 0, 'ACTIVE', '2025-05-01 15:28:28', '2025-05-01 15:28:28'),
(254, 62, 'The current project', 1, 'ACTIVE', '2025-05-01 15:28:28', '2025-05-01 15:28:28'),
(255, 62, 'A new assignment', 0, 'ACTIVE', '2025-05-01 15:28:28', '2025-05-01 15:28:28'),
(256, 62, 'A vacation request', 0, 'ACTIVE', '2025-05-01 15:28:28', '2025-05-01 15:28:28'),
(257, 62, 'Salary increase', 0, 'ACTIVE', '2025-05-01 15:28:28', '2025-05-01 15:28:28'),
(258, 63, 'Next week', 1, 'ACTIVE', '2025-05-01 15:28:28', '2025-05-01 15:28:28'),
(259, 63, 'Tomorrow', 0, 'ACTIVE', '2025-05-01 15:28:28', '2025-05-01 15:28:28'),
(260, 63, 'Today', 0, 'ACTIVE', '2025-05-01 15:28:28', '2025-05-01 15:28:28'),
(261, 63, 'Next month', 0, 'ACTIVE', '2025-05-01 15:28:28', '2025-05-01 15:28:28'),
(262, 64, 'With a polite greeting', 1, 'ACTIVE', '2025-05-01 15:28:28', '2025-05-01 15:28:28'),
(263, 64, 'With an urgent request', 0, 'ACTIVE', '2025-05-01 15:28:28', '2025-05-01 15:28:28'),
(264, 64, 'With a complaint', 0, 'ACTIVE', '2025-05-01 15:28:28', '2025-05-01 15:28:28'),
(265, 64, 'With an apology', 0, 'ACTIVE', '2025-05-01 15:28:28', '2025-05-01 15:28:28'),
(266, 65, 'To apply for a job', 1, 'ACTIVE', '2025-05-01 15:28:42', '2025-05-01 15:28:42'),
(267, 65, 'To resign from a position', 0, 'ACTIVE', '2025-05-01 15:28:42', '2025-05-01 15:28:42'),
(268, 65, 'To request information', 0, 'ACTIVE', '2025-05-01 15:28:42', '2025-05-01 15:28:42'),
(269, 65, 'To make a complaint', 0, 'ACTIVE', '2025-05-01 15:28:42', '2025-05-01 15:28:42'),
(270, 66, 'Sales Manager', 1, 'ACTIVE', '2025-05-01 15:28:42', '2025-05-01 15:28:42'),
(271, 66, 'Marketing Director', 0, 'ACTIVE', '2025-05-01 15:28:42', '2025-05-01 15:28:42'),
(272, 66, 'Customer Service Representative', 0, 'ACTIVE', '2025-05-01 15:28:42', '2025-05-01 15:28:42'),
(273, 66, 'Administrative Assistant', 0, 'ACTIVE', '2025-05-01 15:28:42', '2025-05-01 15:28:42'),
(274, 67, 'To whom it may concern', 1, 'ACTIVE', '2025-05-01 15:28:42', '2025-05-01 15:28:42'),
(275, 67, 'Dear Hiring Manager', 0, 'ACTIVE', '2025-05-01 15:28:42', '2025-05-01 15:28:42'),
(276, 67, 'Hello', 0, 'ACTIVE', '2025-05-01 15:28:42', '2025-05-01 15:28:42'),
(277, 67, 'Dear Sir/Madam', 0, 'ACTIVE', '2025-05-01 15:28:42', '2025-05-01 15:28:42'),
(278, 68, 'A job application letter', 1, 'ACTIVE', '2025-05-01 15:28:42', '2025-05-01 15:28:42'),
(279, 68, 'A resignation letter', 0, 'ACTIVE', '2025-05-01 15:28:42', '2025-05-01 15:28:42'),
(280, 68, 'A thank you letter', 0, 'ACTIVE', '2025-05-01 15:28:42', '2025-05-01 15:28:42'),
(281, 68, 'A complaint letter', 0, 'ACTIVE', '2025-05-01 15:28:42', '2025-05-01 15:28:42'),
(282, 69, 'Rome', 1, 'ACTIVE', '2025-05-01 15:33:47', '2025-05-01 15:33:47'),
(283, 69, 'Paris', 0, 'ACTIVE', '2025-05-01 15:33:47', '2025-05-01 15:33:47'),
(284, 69, 'London', 0, 'ACTIVE', '2025-05-01 15:33:47', '2025-05-01 15:33:47'),
(285, 69, 'Berlin', 0, 'ACTIVE', '2025-05-01 15:33:47', '2025-05-01 15:33:47'),
(286, 70, 'The Colosseum and the local cuisine', 1, 'ACTIVE', '2025-05-01 15:33:47', '2025-05-01 15:33:47'),
(287, 70, 'The shopping malls', 0, 'ACTIVE', '2025-05-01 15:33:47', '2025-05-01 15:33:47'),
(288, 70, 'The modern architecture', 0, 'ACTIVE', '2025-05-01 15:33:47', '2025-05-01 15:33:47'),
(289, 70, 'The nightclubs', 0, 'ACTIVE', '2025-05-01 15:33:47', '2025-05-01 15:33:47'),
(290, 71, 'Full of life and history', 1, 'ACTIVE', '2025-05-01 15:33:47', '2025-05-01 15:33:47'),
(291, 71, 'Quiet and peaceful', 0, 'ACTIVE', '2025-05-01 15:33:47', '2025-05-01 15:33:47'),
(292, 71, 'Industrial and modern', 0, 'ACTIVE', '2025-05-01 15:33:47', '2025-05-01 15:33:47'),
(293, 71, 'Small and unremarkable', 0, 'ACTIVE', '2025-05-01 15:33:47', '2025-05-01 15:33:47'),
(294, 72, 'A travel blog entry', 1, 'ACTIVE', '2025-05-01 15:33:47', '2025-05-01 15:33:47'),
(295, 72, 'A news report', 0, 'ACTIVE', '2025-05-01 15:33:47', '2025-05-01 15:33:47'),
(296, 72, 'A business memo', 0, 'ACTIVE', '2025-05-01 15:33:47', '2025-05-01 15:33:47'),
(297, 72, 'A product review', 0, 'ACTIVE', '2025-05-01 15:33:47', '2025-05-01 15:33:47'),
(298, 73, 'To invite people to a workshop', 1, 'ACTIVE', '2025-05-01 15:34:00', '2025-05-01 15:34:00'),
(299, 73, 'To announce a new product', 0, 'ACTIVE', '2025-05-01 15:34:00', '2025-05-01 15:34:00'),
(300, 73, 'To report on a past event', 0, 'ACTIVE', '2025-05-01 15:34:00', '2025-05-01 15:34:00'),
(301, 73, 'To advertise a job opening', 0, 'ACTIVE', '2025-05-01 15:34:00', '2025-05-01 15:34:00'),
(302, 74, 'August 12th', 1, 'ACTIVE', '2025-05-01 15:34:00', '2025-05-01 15:34:00'),
(303, 74, 'July 15th', 0, 'ACTIVE', '2025-05-01 15:34:00', '2025-05-01 15:34:00'),
(304, 74, 'September 1st', 0, 'ACTIVE', '2025-05-01 15:34:00', '2025-05-01 15:34:00'),
(305, 74, 'October 20th', 0, 'ACTIVE', '2025-05-01 15:34:01', '2025-05-01 15:34:01'),
(306, 75, 'Marketing Strategies', 1, 'ACTIVE', '2025-05-01 15:34:01', '2025-05-01 15:34:01'),
(307, 75, 'Financial Planning', 0, 'ACTIVE', '2025-05-01 15:34:01', '2025-05-01 15:34:01'),
(308, 75, 'Technical Writing', 0, 'ACTIVE', '2025-05-01 15:34:01', '2025-05-01 15:34:01'),
(309, 75, 'Leadership Skills', 0, 'ACTIVE', '2025-05-01 15:34:01', '2025-05-01 15:34:01'),
(310, 76, 'At the main office', 1, 'ACTIVE', '2025-05-01 15:34:01', '2025-05-01 15:34:01'),
(311, 76, 'At a hotel', 0, 'ACTIVE', '2025-05-01 15:34:01', '2025-05-01 15:34:01'),
(312, 76, 'Online', 0, 'ACTIVE', '2025-05-01 15:34:01', '2025-05-01 15:34:01'),
(313, 76, 'At a conference center', 0, 'ACTIVE', '2025-05-01 15:34:01', '2025-05-01 15:34:01'),
(314, 77, 'All staff', 1, 'ACTIVE', '2025-05-01 15:34:14', '2025-05-01 15:34:14'),
(315, 77, 'Only managers', 0, 'ACTIVE', '2025-05-01 15:34:14', '2025-05-01 15:34:14'),
(316, 77, 'New employees only', 0, 'ACTIVE', '2025-05-01 15:34:15', '2025-05-01 15:34:15'),
(317, 77, 'The IT department', 0, 'ACTIVE', '2025-05-01 15:34:15', '2025-05-01 15:34:15'),
(318, 78, 'Online security training', 1, 'ACTIVE', '2025-05-01 15:34:15', '2025-05-01 15:34:15'),
(319, 78, 'Customer service training', 0, 'ACTIVE', '2025-05-01 15:34:15', '2025-05-01 15:34:15'),
(320, 78, 'Sales training', 0, 'ACTIVE', '2025-05-01 15:34:15', '2025-05-01 15:34:15'),
(321, 78, 'Diversity training', 0, 'ACTIVE', '2025-05-01 15:34:15', '2025-05-01 15:34:15'),
(322, 79, 'By the end of the month', 1, 'ACTIVE', '2025-05-01 15:34:15', '2025-05-01 15:34:15'),
(323, 79, 'Within a week', 0, 'ACTIVE', '2025-05-01 15:34:15', '2025-05-01 15:34:15'),
(324, 79, 'By the end of the year', 0, 'ACTIVE', '2025-05-01 15:34:15', '2025-05-01 15:34:15'),
(325, 79, 'Within two weeks', 0, 'ACTIVE', '2025-05-01 15:34:15', '2025-05-01 15:34:15'),
(326, 80, 'A company memo', 1, 'ACTIVE', '2025-05-01 15:34:15', '2025-05-01 15:34:15'),
(327, 80, 'A job advertisement', 0, 'ACTIVE', '2025-05-01 15:34:15', '2025-05-01 15:34:15'),
(328, 80, 'A newsletter', 0, 'ACTIVE', '2025-05-01 15:34:15', '2025-05-01 15:34:15'),
(329, 80, 'A meeting agenda', 0, 'ACTIVE', '2025-05-01 15:34:15', '2025-05-01 15:34:15'),
(330, 81, 'SmartWatch 2.0', 1, 'ACTIVE', '2025-05-01 15:34:27', '2025-05-01 15:34:27'),
(331, 81, 'Fitness Tracker Pro', 0, 'ACTIVE', '2025-05-01 15:34:27', '2025-05-01 15:34:27'),
(332, 81, 'Phone X', 0, 'ACTIVE', '2025-05-01 15:34:27', '2025-05-01 15:34:27'),
(333, 81, 'Tablet Mini', 0, 'ACTIVE', '2025-05-01 15:34:27', '2025-05-01 15:34:27'),
(334, 82, 'Water resistance', 1, 'ACTIVE', '2025-05-01 15:34:27', '2025-05-01 15:34:27'),
(335, 82, 'Sleek design', 0, 'ACTIVE', '2025-05-01 15:34:27', '2025-05-01 15:34:27'),
(336, 82, 'Heart rate monitor', 0, 'ACTIVE', '2025-05-01 15:34:27', '2025-05-01 15:34:27'),
(337, 82, 'Extended battery life', 0, 'ACTIVE', '2025-05-01 15:34:27', '2025-05-01 15:34:27'),
(338, 83, 'Sleek', 1, 'ACTIVE', '2025-05-01 15:34:28', '2025-05-01 15:34:28'),
(339, 83, 'Bulky', 0, 'ACTIVE', '2025-05-01 15:34:28', '2025-05-01 15:34:28'),
(340, 83, 'Colorful', 0, 'ACTIVE', '2025-05-01 15:34:28', '2025-05-01 15:34:28'),
(341, 83, 'Plain', 0, 'ACTIVE', '2025-05-01 15:34:28', '2025-05-01 15:34:28'),
(342, 84, 'It has extended life', 1, 'ACTIVE', '2025-05-01 15:34:28', '2025-05-01 15:34:28'),
(343, 84, 'It charges wirelessly', 0, 'ACTIVE', '2025-05-01 15:34:28', '2025-05-01 15:34:28'),
(344, 84, 'It is removable', 0, 'ACTIVE', '2025-05-01 15:34:28', '2025-05-01 15:34:28'),
(345, 84, 'It is solar-powered', 0, 'ACTIVE', '2025-05-01 15:34:28', '2025-05-01 15:34:28'),
(346, 85, 'The local government', 1, 'ACTIVE', '2025-05-01 15:34:40', '2025-05-01 15:34:40'),
(347, 85, 'A private company', 0, 'ACTIVE', '2025-05-01 15:34:40', '2025-05-01 15:34:40'),
(348, 85, 'A community group', 0, 'ACTIVE', '2025-05-01 15:34:40', '2025-05-01 15:34:40'),
(349, 85, 'A national organization', 0, 'ACTIVE', '2025-05-01 15:34:40', '2025-05-01 15:34:40'),
(350, 86, 'Park renovation', 1, 'ACTIVE', '2025-05-01 15:34:40', '2025-05-01 15:34:40'),
(351, 86, 'Road construction', 0, 'ACTIVE', '2025-05-01 15:34:40', '2025-05-01 15:34:40'),
(352, 86, 'School building', 0, 'ACTIVE', '2025-05-01 15:34:40', '2025-05-01 15:34:40'),
(353, 86, 'Hospital expansion', 0, 'ACTIVE', '2025-05-01 15:34:40', '2025-05-01 15:34:40'),
(354, 87, 'Next spring', 1, 'ACTIVE', '2025-05-01 15:34:40', '2025-05-01 15:34:40'),
(355, 87, 'This summer', 0, 'ACTIVE', '2025-05-01 15:34:40', '2025-05-01 15:34:40'),
(356, 87, 'Next fall', 0, 'ACTIVE', '2025-05-01 15:34:40', '2025-05-01 15:34:40'),
(357, 87, 'This winter', 0, 'ACTIVE', '2025-05-01 15:34:40', '2025-05-01 15:34:40'),
(358, 88, 'A news article', 1, 'ACTIVE', '2025-05-01 15:34:40', '2025-05-01 15:34:40'),
(359, 88, 'An advertisement', 0, 'ACTIVE', '2025-05-01 15:34:40', '2025-05-01 15:34:40'),
(360, 88, 'A personal letter', 0, 'ACTIVE', '2025-05-01 15:34:40', '2025-05-01 15:34:40'),
(361, 88, 'A research paper', 0, 'ACTIVE', '2025-05-01 15:34:40', '2025-05-01 15:34:40'),
(362, 86, 'Download the setup file', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(363, 86, 'Double-click the setup file', 1, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(364, 86, 'Read the manual first', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(365, 86, 'Restart your computer', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(366, 87, 'By double-clicking it', 1, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(367, 87, 'By right-clicking it', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(368, 87, 'By dragging it to the trash', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(369, 87, 'By renaming it', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(370, 88, 'The on-screen instructions', 1, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(371, 88, 'A printed manual', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(372, 88, 'A customer service representative', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(373, 88, 'The software developer', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(374, 89, 'A user manual', 1, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(375, 89, 'A novel', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(376, 89, 'A newspaper article', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(377, 89, 'A hotel review', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(378, 90, 'It was clean and well-located', 1, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(379, 90, 'The service was excellent', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(380, 90, 'The food was delicious', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(381, 90, 'The rooms were spacious', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(382, 91, 'The cleanliness', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(383, 91, 'The service', 1, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(384, 91, 'The location', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(385, 91, 'The price', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(386, 92, 'Poor', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(387, 92, 'Well-located', 1, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(388, 92, 'Remote', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(389, 92, 'Not mentioned', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(390, 93, 'A customer review', 1, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(391, 93, 'A news report', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(392, 93, 'An advertisement', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(393, 93, 'A scientific article', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(394, 94, 'Log in to their account', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(395, 94, 'Reset their password', 1, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(396, 94, 'Change their username', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(397, 94, 'Delete their account', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(398, 95, 'On \"Forgot Password\"', 1, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(399, 95, 'On \"Create Account\"', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(400, 95, 'On \"Help Center\"', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(401, 95, 'On \"Settings\"', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(402, 96, 'Contact customer service', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(403, 96, 'Follow the instructions', 1, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(404, 96, 'Restart the computer', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(405, 96, 'Wait for an email', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(406, 97, 'A Frequently Asked Questions section', 1, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(407, 97, 'A legal document', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(408, 97, 'A personal letter', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(409, 97, 'A product description', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(410, 98, 'To remind about an appointment', 1, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(411, 98, 'To cancel an appointment', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(412, 98, 'To schedule a new appointment', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(413, 98, 'To complain about a service', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(414, 99, 'Monday at 10 AM', 1, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(415, 99, 'Tuesday at 2 PM', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(416, 99, 'Friday at 9 AM', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(417, 99, 'Not specified', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(418, 100, 'Dentist appointment', 1, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(419, 100, 'Doctor\'s checkup', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(420, 100, 'Hair salon appointment', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(421, 100, 'Job interview', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(422, 101, 'Friendly', 1, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(423, 101, 'Angry', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(424, 101, 'Formal', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(425, 101, 'Humorous', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(426, 102, 'Sunny and warm', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(427, 102, 'Dark and stormy', 1, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(428, 102, 'Snowy and cold', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(429, 102, 'Foggy and damp', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(430, 103, 'John', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(431, 103, 'Sarah', 1, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(432, 103, 'Michael', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(433, 103, 'Emily', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(434, 104, 'A phone call', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(435, 104, 'A knock on the door', 1, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(436, 104, 'A power outage', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(437, 104, 'A car accident', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(438, 105, 'The beginning of a story', 1, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(439, 105, 'A news report', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(440, 105, 'A poem', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(441, 105, 'A scientific article', 0, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(442, 109, 'Due to maintenance work', 1, 'ACTIVE', '2025-05-01 16:15:11', '2025-05-01 16:15:11'),
(444, 110, 'Partly cloudy', 1, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(445, 110, 'Sunny', 0, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(446, 110, 'Rainy', 0, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(447, 110, 'Snowy', 0, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(448, 111, '24°C', 1, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(449, 111, '18°C', 0, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(450, 111, '30°C', 0, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(451, 111, '15°C', 0, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(452, 112, 'In the afternoon', 1, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(453, 112, 'In the morning', 0, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(454, 112, 'At night', 0, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(455, 112, 'Around noon', 0, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(456, 113, 'Light showers', 1, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(457, 113, 'Heavy rain', 0, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(458, 113, 'Hail', 0, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(459, 113, 'Snow', 0, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(460, 114, 'The stairs', 1, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(461, 114, 'Elevators', 0, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(462, 114, 'Windows', 0, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(463, 114, 'Fire extinguishers', 0, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(464, 115, 'Elevators', 1, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(465, 115, 'Stairs', 0, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(466, 115, 'Emergency exits', 0, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(467, 115, 'Fire alarms', 0, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(468, 116, 'Follow emergency exit signs', 1, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(469, 116, 'Run to the nearest window', 0, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(470, 116, 'Wait for instructions', 0, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(471, 116, 'Use the service elevator', 0, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(472, 117, 'To ensure safe evacuation during a fire', 1, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(473, 117, 'To prevent fires from starting', 0, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(474, 117, 'To teach firefighting techniques', 0, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(475, 117, 'To explain building maintenance', 0, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(476, 118, 'Marketing and IT', 1, 'ACTIVE', '2025-05-01 16:26:05', '2025-05-01 16:26:05'),
(477, 118, 'Finance and HR', 0, 'ACTIVE', '2025-05-01 16:26:05', '2025-05-01 16:26:05'),
(478, 118, 'Engineering and Design', 0, 'ACTIVE', '2025-05-01 16:26:05', '2025-05-01 16:26:05'),
(479, 118, 'Sales and Operations', 0, 'ACTIVE', '2025-05-01 16:26:05', '2025-05-01 16:26:05'),
(480, 119, 'May 30th', 1, 'ACTIVE', '2025-05-01 16:26:05', '2025-05-01 16:26:05'),
(481, 119, 'June 15th', 0, 'ACTIVE', '2025-05-01 16:26:05', '2025-05-01 16:26:05'),
(482, 119, 'April 30th', 0, 'ACTIVE', '2025-05-01 16:26:05', '2025-05-01 16:26:05'),
(483, 119, 'July 1st', 0, 'ACTIVE', '2025-05-01 16:26:05', '2025-05-01 16:26:05'),
(484, 120, 'Undergraduate students', 1, 'ACTIVE', '2025-05-01 16:26:05', '2025-05-01 16:26:05'),
(485, 120, 'High school students', 0, 'ACTIVE', '2025-05-01 16:26:05', '2025-05-01 16:26:05'),
(486, 120, 'Graduate students', 0, 'ACTIVE', '2025-05-01 16:26:05', '2025-05-01 16:26:05'),
(487, 120, 'Professors', 0, 'ACTIVE', '2025-05-01 16:26:05', '2025-05-01 16:26:05'),
(488, 121, 'Summer internships', 1, 'ACTIVE', '2025-05-01 16:26:05', '2025-05-01 16:26:05'),
(489, 121, 'Winter internships', 0, 'ACTIVE', '2025-05-01 16:26:05', '2025-05-01 16:26:05'),
(490, 121, 'Year-long internships', 0, 'ACTIVE', '2025-05-01 16:26:05', '2025-05-01 16:26:05'),
(491, 121, 'Part-time internships', 0, 'ACTIVE', '2025-05-01 16:26:05', '2025-05-01 16:26:05'),
(492, 122, 'Five', 1, 'ACTIVE', '2025-05-01 16:26:18', '2025-05-01 16:26:18'),
(493, 122, 'Three', 0, 'ACTIVE', '2025-05-01 16:26:18', '2025-05-01 16:26:18'),
(494, 122, 'Seven', 0, 'ACTIVE', '2025-05-01 16:26:18', '2025-05-01 16:26:18'),
(495, 122, 'Ten', 0, 'ACTIVE', '2025-05-01 16:26:18', '2025-05-01 16:26:18'),
(496, 123, 'Under 30 minutes', 1, 'ACTIVE', '2025-05-01 16:26:18', '2025-05-01 16:26:18'),
(497, 123, 'About 1 hour', 0, 'ACTIVE', '2025-05-01 16:26:18', '2025-05-01 16:26:18'),
(498, 123, '15 minutes', 0, 'ACTIVE', '2025-05-01 16:26:18', '2025-05-01 16:26:18'),
(499, 123, '45 minutes', 0, 'ACTIVE', '2025-05-01 16:26:18', '2025-05-01 16:26:18'),
(500, 124, 'Pasta recipe', 1, 'ACTIVE', '2025-05-01 16:26:18', '2025-05-01 16:26:18'),
(501, 124, 'Salad recipe', 0, 'ACTIVE', '2025-05-01 16:26:18', '2025-05-01 16:26:18'),
(502, 124, 'Dessert recipe', 0, 'ACTIVE', '2025-05-01 16:26:18', '2025-05-01 16:26:18'),
(503, 124, 'Soup recipe', 0, 'ACTIVE', '2025-05-01 16:26:18', '2025-05-01 16:26:18'),
(504, 125, 'Easy-to-make', 1, 'ACTIVE', '2025-05-01 16:26:18', '2025-05-01 16:26:18'),
(505, 125, 'Complicated', 0, 'ACTIVE', '2025-05-01 16:26:18', '2025-05-01 16:26:18'),
(506, 125, 'Time-consuming', 0, 'ACTIVE', '2025-05-01 16:26:18', '2025-05-01 16:26:18'),
(507, 125, 'Requires special skills', 0, 'ACTIVE', '2025-05-01 16:26:18', '2025-05-01 16:26:18'),
(508, 126, 'In fire lanes and loading zones', 1, 'ACTIVE', '2025-05-01 16:26:43', '2025-05-01 16:26:43'),
(509, 126, 'In designated parking spots', 0, 'ACTIVE', '2025-05-01 16:26:43', '2025-05-01 16:26:43'),
(510, 126, 'On the sidewalk', 0, 'ACTIVE', '2025-05-01 16:26:43', '2025-05-01 16:26:43'),
(511, 126, 'In the parking garage', 0, 'ACTIVE', '2025-05-01 16:26:43', '2025-05-01 16:26:43'),
(512, 127, 'They will be towed', 1, 'ACTIVE', '2025-05-01 16:26:43', '2025-05-01 16:26:43'),
(513, 127, 'They will receive a warning', 0, 'ACTIVE', '2025-05-01 16:26:43', '2025-05-01 16:26:43'),
(514, 127, 'They will be fined immediately', 0, 'ACTIVE', '2025-05-01 16:26:43', '2025-05-01 16:26:43'),
(515, 127, 'They will be locked', 0, 'ACTIVE', '2025-05-01 16:26:43', '2025-05-01 16:26:43'),
(516, 128, 'The vehicle owner', 1, 'ACTIVE', '2025-05-01 16:26:43', '2025-05-01 16:26:43'),
(517, 128, 'The parking company', 0, 'ACTIVE', '2025-05-01 16:26:43', '2025-05-01 16:26:43'),
(518, 128, 'The city government', 0, 'ACTIVE', '2025-05-01 16:26:43', '2025-05-01 16:26:43'),
(519, 128, 'The insurance company', 0, 'ACTIVE', '2025-05-01 16:26:43', '2025-05-01 16:26:43'),
(520, 129, 'To inform about parking rules', 1, 'ACTIVE', '2025-05-01 16:26:43', '2025-05-01 16:26:43'),
(521, 129, 'To advertise parking spaces', 0, 'ACTIVE', '2025-05-01 16:26:43', '2025-05-01 16:26:43'),
(522, 129, 'To announce new parking fees', 0, 'ACTIVE', '2025-05-01 16:26:43', '2025-05-01 16:26:43'),
(523, 129, 'To promote carpooling', 0, 'ACTIVE', '2025-05-01 16:26:43', '2025-05-01 16:26:43'),
(524, 130, 'At 9:00 AM', 1, 'ACTIVE', '2025-05-01 16:26:54', '2025-05-01 16:26:54'),
(525, 130, 'At 10:00 AM', 0, 'ACTIVE', '2025-05-01 16:26:54', '2025-05-01 16:26:54'),
(526, 130, 'At 8:30 AM', 0, 'ACTIVE', '2025-05-01 16:26:54', '2025-05-01 16:26:54'),
(527, 130, 'At 9:30 AM', 0, 'ACTIVE', '2025-05-01 16:26:54', '2025-05-01 16:26:54'),
(528, 131, 'Breakout sessions', 1, 'ACTIVE', '2025-05-01 16:26:54', '2025-05-01 16:26:54'),
(529, 131, 'Lunch break', 0, 'ACTIVE', '2025-05-01 16:26:54', '2025-05-01 16:26:54'),
(530, 131, 'Closing ceremony', 0, 'ACTIVE', '2025-05-01 16:26:54', '2025-05-01 16:26:54'),
(531, 131, 'Networking event', 0, 'ACTIVE', '2025-05-01 16:26:54', '2025-05-01 16:26:54'),
(532, 132, 'Business strategy and innovation', 1, 'ACTIVE', '2025-05-01 16:26:55', '2025-05-01 16:26:55'),
(533, 132, 'Marketing and sales', 0, 'ACTIVE', '2025-05-01 16:26:55', '2025-05-01 16:26:55'),
(534, 132, 'Technology trends', 0, 'ACTIVE', '2025-05-01 16:26:55', '2025-05-01 16:26:55'),
(535, 132, 'Human resources', 0, 'ACTIVE', '2025-05-01 16:26:55', '2025-05-01 16:26:55'),
(536, 133, 'A conference', 1, 'ACTIVE', '2025-05-01 16:26:55', '2025-05-01 16:26:55'),
(537, 133, 'A workshop', 0, 'ACTIVE', '2025-05-01 16:26:55', '2025-05-01 16:26:55'),
(538, 133, 'A seminar', 0, 'ACTIVE', '2025-05-01 16:26:55', '2025-05-01 16:26:55'),
(539, 133, 'A training session', 0, 'ACTIVE', '2025-05-01 16:26:55', '2025-05-01 16:26:55'),
(540, 134, 'Next Tuesday at 3:00 PM', 1, 'ACTIVE', '2025-05-01 16:27:07', '2025-05-01 16:27:07'),
(541, 134, 'This Monday at 2:00 PM', 0, 'ACTIVE', '2025-05-01 16:27:07', '2025-05-01 16:27:07'),
(542, 134, 'Next Wednesday at 10:00 AM', 0, 'ACTIVE', '2025-05-01 16:27:07', '2025-05-01 16:27:07'),
(543, 134, 'This Friday at 4:00 PM', 0, 'ACTIVE', '2025-05-01 16:27:07', '2025-05-01 16:27:07'),
(544, 135, 'In Room 402', 1, 'ACTIVE', '2025-05-01 16:27:07', '2025-05-01 16:27:07'),
(545, 135, 'In the main auditorium', 0, 'ACTIVE', '2025-05-01 16:27:07', '2025-05-01 16:27:07'),
(546, 135, 'In the cafeteria', 0, 'ACTIVE', '2025-05-01 16:27:07', '2025-05-01 16:27:07'),
(547, 135, 'In the conference room', 0, 'ACTIVE', '2025-05-01 16:27:07', '2025-05-01 16:27:07'),
(548, 136, 'A notebook and pen', 1, 'ACTIVE', '2025-05-01 16:27:07', '2025-05-01 16:27:07'),
(549, 136, 'A laptop', 0, 'ACTIVE', '2025-05-01 16:27:07', '2025-05-01 16:27:07'),
(550, 136, 'A textbook', 0, 'ACTIVE', '2025-05-01 16:27:07', '2025-05-01 16:27:07'),
(551, 136, 'A calculator', 0, 'ACTIVE', '2025-05-01 16:27:07', '2025-05-01 16:27:07'),
(552, 137, 'To remind about a training session', 1, 'ACTIVE', '2025-05-01 16:27:07', '2025-05-01 16:27:07'),
(553, 137, 'To announce a new training program', 0, 'ACTIVE', '2025-05-01 16:27:07', '2025-05-01 16:27:07'),
(554, 137, 'To cancel a training session', 0, 'ACTIVE', '2025-05-01 16:27:07', '2025-05-01 16:27:07'),
(555, 137, 'To request feedback on training', 0, 'ACTIVE', '2025-05-01 16:27:07', '2025-05-01 16:27:07'),
(556, 138, 'Bring reusable bags when shopping', 1, 'ACTIVE', '2025-05-01 16:32:19', '2025-05-01 16:32:19'),
(557, 138, 'Recycle all your waste', 0, 'ACTIVE', '2025-05-01 16:32:19', '2025-05-01 16:32:19'),
(558, 138, 'Use plastic bags less frequently', 0, 'ACTIVE', '2025-05-01 16:32:19', '2025-05-01 16:32:19'),
(559, 138, 'Buy only organic products', 0, 'ACTIVE', '2025-05-01 16:32:19', '2025-05-01 16:32:19'),
(560, 139, 'A big impact on the environment', 1, 'ACTIVE', '2025-05-01 16:32:19', '2025-05-01 16:32:19'),
(561, 139, 'No significant impact', 0, 'ACTIVE', '2025-05-01 16:32:19', '2025-05-01 16:32:19'),
(562, 139, 'Only a local impact', 0, 'ACTIVE', '2025-05-01 16:32:19', '2025-05-01 16:32:19'),
(563, 139, 'A temporary effect', 0, 'ACTIVE', '2025-05-01 16:32:19', '2025-05-01 16:32:19'),
(564, 140, 'When shopping', 1, 'ACTIVE', '2025-05-01 16:32:19', '2025-05-01 16:32:19'),
(565, 140, 'At home', 0, 'ACTIVE', '2025-05-01 16:32:19', '2025-05-01 16:32:19'),
(566, 140, 'In the office', 0, 'ACTIVE', '2025-05-01 16:32:19', '2025-05-01 16:32:19'),
(567, 140, 'While traveling', 0, 'ACTIVE', '2025-05-01 16:32:19', '2025-05-01 16:32:19');
INSERT INTO `answers` (`pk_answer`, `question_fk`, `answer_text`, `is_correct`, `status`, `created_at`, `updated_at`) VALUES
(568, 141, 'To reduce waste', 1, 'ACTIVE', '2025-05-01 16:32:19', '2025-05-01 16:32:19'),
(569, 141, 'To save money', 0, 'ACTIVE', '2025-05-01 16:32:19', '2025-05-01 16:32:19'),
(570, 141, 'To promote a brand', 0, 'ACTIVE', '2025-05-01 16:32:19', '2025-05-01 16:32:19'),
(571, 141, 'To organize community events', 0, 'ACTIVE', '2025-05-01 16:32:19', '2025-05-01 16:32:19'),
(572, 142, 'Black leather wallet', 1, 'ACTIVE', '2025-05-01 16:32:37', '2025-05-01 16:32:37'),
(573, 142, 'Brown leather bag', 0, 'ACTIVE', '2025-05-01 16:32:37', '2025-05-01 16:32:37'),
(574, 142, 'Silver keychain', 0, 'ACTIVE', '2025-05-01 16:32:37', '2025-05-01 16:32:37'),
(575, 142, 'Blue backpack', 0, 'ACTIVE', '2025-05-01 16:32:37', '2025-05-01 16:32:37'),
(576, 143, 'Near Central Park', 1, 'ACTIVE', '2025-05-01 16:32:37', '2025-05-01 16:32:37'),
(577, 143, 'In a shopping mall', 0, 'ACTIVE', '2025-05-01 16:32:37', '2025-05-01 16:32:37'),
(578, 143, 'At a bus station', 0, 'ACTIVE', '2025-05-01 16:32:37', '2025-05-01 16:32:37'),
(579, 143, 'In a restaurant', 0, 'ACTIVE', '2025-05-01 16:32:37', '2025-05-01 16:32:37'),
(580, 144, 'Call 555-0198', 1, 'ACTIVE', '2025-05-01 16:32:37', '2025-05-01 16:32:37'),
(581, 144, 'Take it to the police', 0, 'ACTIVE', '2025-05-01 16:32:37', '2025-05-01 16:32:37'),
(582, 144, 'Leave it where you found it', 0, 'ACTIVE', '2025-05-01 16:32:37', '2025-05-01 16:32:37'),
(583, 144, 'Post about it on social media', 0, 'ACTIVE', '2025-05-01 16:32:37', '2025-05-01 16:32:37'),
(584, 145, 'A reward', 1, 'ACTIVE', '2025-05-01 16:32:37', '2025-05-01 16:32:37'),
(585, 145, 'A thank you note', 0, 'ACTIVE', '2025-05-01 16:32:37', '2025-05-01 16:32:37'),
(586, 145, 'A dinner invitation', 0, 'ACTIVE', '2025-05-01 16:32:37', '2025-05-01 16:32:37'),
(587, 145, 'Nothing is mentioned', 0, 'ACTIVE', '2025-05-01 16:32:37', '2025-05-01 16:32:37'),
(588, 146, 'Getting coffee', 1, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(589, 146, 'Eating breakfast', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(590, 146, 'Taking a shower', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(591, 146, 'Driving to work', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(592, 147, 'Not to be late', 1, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(593, 147, 'To bring documents', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(594, 147, 'To call a client', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(595, 147, 'To prepare a presentation', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(596, 148, 'To work', 1, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(597, 148, 'To school', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(598, 148, 'To a restaurant', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(599, 148, 'To a meeting', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(600, 149, 'Morning', 1, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(601, 149, 'Afternoon', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(602, 149, 'Evening', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(603, 149, 'Night', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(604, 150, 'An assignment', 1, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(605, 150, 'A test', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(606, 150, 'A field trip', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(607, 150, 'A school event', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(608, 151, 'Submit an assignment', 1, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(609, 151, 'Take an exam', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(610, 151, 'Read a book', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(611, 151, 'Prepare a presentation', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(612, 152, 'By noon', 1, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(613, 152, 'By the end of the day', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(614, 152, 'Tomorrow morning', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(615, 152, 'Next week', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(616, 153, 'In a classroom', 1, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(617, 153, 'In a library', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(618, 153, 'In an office', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(619, 153, 'In a cafeteria', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(620, 154, 'Open a savings account', 1, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(621, 154, 'Withdraw money', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(622, 154, 'Apply for a loan', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(623, 154, 'Exchange currency', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(624, 155, 'Identification', 1, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(625, 155, 'A deposit', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(626, 155, 'A signature', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(627, 155, 'A phone number', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(628, 156, 'At a bank', 1, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(629, 156, 'At a post office', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(630, 156, 'At a store', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(631, 156, 'At a hotel', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(632, 157, 'An ID', 1, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(633, 157, 'A credit card', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(634, 157, 'A passport photo', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(635, 157, 'A bank statement', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(636, 158, 'At an airport', 1, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(637, 158, 'At a train station', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(638, 158, 'At a hotel', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(639, 158, 'At a bus terminal', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(640, 159, 'Passport and ticket', 1, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(641, 159, 'Boarding pass', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(642, 159, 'Luggage tag', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(643, 159, 'Payment', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(644, 160, 'Enjoy your flight', 1, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(645, 160, 'Have a nice day', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(646, 160, 'See you soon', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(647, 160, 'Bon voyage', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(648, 161, 'Checking in for a flight', 1, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(649, 161, 'Picking up luggage', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(650, 161, 'Booking a ticket', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(651, 161, 'Reporting lost items', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(652, 162, 'He collapsed', 1, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(653, 162, 'He fainted', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(654, 162, 'He was injured', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(655, 162, 'He had a seizure', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(656, 163, 'Jogging', 1, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(657, 163, 'Working', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(658, 163, 'Eating', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(659, 163, 'Driving', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(660, 164, 'Calling an ambulance', 1, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(661, 164, 'Giving first aid', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(662, 164, 'Taking him to hospital', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(663, 164, 'Calling his family', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(664, 165, 'Witnesses to an emergency', 1, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(665, 165, 'Doctor and nurse', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(666, 165, 'Paramedics', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(667, 165, 'Family members', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(668, 166, 'Internet is down', 1, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(669, 166, 'Computer is slow', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(670, 166, 'Printer isn\'t working', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(671, 166, 'Phone has no signal', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(672, 167, 'Run a line test', 1, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(673, 167, 'Send a technician', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(674, 167, 'Reset the connection', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(675, 167, 'Replace the modem', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(676, 168, 'Thanks, I\'ll wait', 1, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(677, 168, 'Please hurry', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(678, 168, 'How long will it take?', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(679, 168, 'Can you call me back?', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(680, 169, 'Customer and support agent', 1, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(681, 169, 'Colleagues', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(682, 169, 'Friends', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(683, 169, 'Manager and employee', 0, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(684, 170, 'Automatic', 1, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(685, 170, 'Manual', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(686, 170, 'Electric', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(687, 170, 'Hybrid', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(688, 171, 'For three days', 1, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(689, 171, 'For one week', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(690, 171, 'For a month', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(691, 171, 'Just for the day', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(692, 172, 'To rent a car', 1, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(693, 172, 'To buy a car', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(694, 172, 'To repair a car', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(695, 172, 'To sell a car', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(696, 173, 'Transmission preference', 1, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(697, 173, 'Car color', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(698, 173, 'Insurance options', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(699, 173, 'Fuel type', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(700, 174, 'The candidate\'s five-year plan', 1, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(701, 174, 'Previous work experience', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(702, 174, 'Salary expectations', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(703, 174, 'Educational background', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(704, 175, 'Positively (\"Great answer\")', 1, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(705, 175, 'Neutrally (\"I see\")', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(706, 175, 'Negatively (\"That\'s not what we\'re looking for\")', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(707, 175, 'With confusion (\"Could you explain more?\")', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(708, 176, 'Lead a successful team', 1, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(709, 176, 'Start their own business', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(710, 176, 'Work independently', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(711, 176, 'Retire early', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(712, 177, 'Five years', 1, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(713, 177, 'One year', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(714, 177, 'Ten years', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(715, 177, 'Six months', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(716, 178, 'Their child\'s performance in class', 1, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(717, 178, 'The school\'s lunch menu', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(718, 178, 'Upcoming school events', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(719, 178, 'Transportation options', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(720, 179, 'Very bright but needs to focus more', 1, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(721, 179, 'Struggling with all subjects', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(722, 179, 'The best in the class', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(723, 179, 'Not participating at all', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(724, 180, 'Work on improving focus', 1, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(725, 180, 'Hire a tutor', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(726, 180, 'Change schools', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(727, 180, 'Nothing specific', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(728, 181, 'Sam', 1, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(729, 181, 'John', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(730, 181, 'Lisa', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(731, 181, 'Michael', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(732, 182, 'On the train', 1, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(733, 182, 'At the bus station', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(734, 182, 'In a taxi', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(735, 182, 'At the airport', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(736, 183, 'A backpack', 1, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(737, 183, 'A suitcase', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(738, 183, 'A wallet', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(739, 183, 'A phone', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(740, 184, 'Blue', 1, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(741, 184, 'Red', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(742, 184, 'Black', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(743, 184, 'Green', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(744, 185, 'A laptop', 1, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(745, 185, 'Books', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(746, 185, 'Clothes', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(747, 185, 'Documents', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(748, 186, 'Finalizing the guest list', 1, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(749, 186, 'Choosing a venue', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(750, 186, 'Selecting a menu', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(751, 186, 'Sending invitations', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(752, 187, 'By email', 1, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(753, 187, 'By text message', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(754, 187, 'In person', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(755, 187, 'By phone call', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(756, 188, '\"Thanks\"', 1, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(757, 188, '\"Goodbye\"', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(758, 188, '\"See you later\"', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(759, 188, '\"That\'s all\"', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(760, 189, 'Cooperative and polite', 1, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(761, 189, 'Argumentative', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(762, 189, 'Indifferent', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(763, 189, 'Excited and enthusiastic', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(764, 190, 'A library card', 1, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(765, 190, 'A book', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(766, 190, 'A study room', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(767, 190, 'A magazine', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(768, 191, 'Fill out a form', 1, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(769, 191, 'Show identification', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(770, 191, 'Pay a fee', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(771, 191, 'Wait in line', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(772, 192, 'Agrees to do it (\"Will do\")', 1, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(773, 192, 'Asks for help', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(774, 192, 'Complains', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(775, 192, 'Requests more information', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(776, 193, 'At a library', 1, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(777, 193, 'At a bookstore', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(778, 193, 'At a school', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(779, 193, 'At an office', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(780, 194, 'Eggs', 1, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(781, 194, 'Milk', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(782, 194, 'Bread', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(783, 194, 'Fruit', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(784, 195, 'In the cart', 1, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(785, 195, 'On the shelf', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(786, 195, 'At the checkout', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(787, 195, 'In the bag', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(788, 196, 'Check out', 1, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(789, 196, 'Continue shopping', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(790, 196, 'Ask for assistance', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(791, 196, 'Return an item', 0, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(796, 1, 'test answer', 0, 'ACTIVE', '2025-05-01 17:14:33', '2025-05-01 17:14:33'),
(801, 197, 'Shoppers together', 1, 'ACTIVE', '2025-05-08 21:46:49', '2025-05-08 21:46:49'),
(802, 197, 'Customer and cashier', 0, 'ACTIVE', '2025-05-08 21:46:49', '2025-05-08 21:46:49'),
(803, 197, 'Store manager and employee', 0, 'ACTIVE', '2025-05-08 21:46:49', '2025-05-08 21:46:49'),
(804, 197, 'Strangers', 0, 'ACTIVE', '2025-05-08 21:46:49', '2025-05-08 21:46:49');

-- --------------------------------------------------------

--
-- Table structure for table `api_usage_log`
--

CREATE TABLE `api_usage_log` (
  `pk_log` int(11) NOT NULL,
  `fk_user` int(11) NOT NULL,
  `endpoint` varchar(50) NOT NULL,
  `request_date` date NOT NULL,
  `count` int(11) NOT NULL DEFAULT 1,
  `last_request_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `api_usage_log`
--

INSERT INTO `api_usage_log` (`pk_log`, `fk_user`, `endpoint`, `request_date`, `count`, `last_request_at`) VALUES
(1, 16, 'ai_comment', '2025-06-16', 5, '2025-06-16 23:27:15'),
(2, 18, 'ai_comment', '2025-06-16', 5, '2025-06-16 23:49:14'),
(3, 18, 'ai_comment', '2025-06-17', 3, '2025-06-17 00:24:27'),
(4, 16, 'ai_comment', '2025-06-17', 1, '2025-06-17 13:48:12'),
(5, 16, 'ai_comment', '2025-06-21', 1, '2025-06-21 12:47:45');

-- --------------------------------------------------------

--
-- Table structure for table `level_history`
--

CREATE TABLE `level_history` (
  `pk_history` int(11) NOT NULL,
  `level_fk` int(11) DEFAULT NULL,
  `user_fk` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `level_history`
--

INSERT INTO `level_history` (`pk_history`, `level_fk`, `user_fk`, `created_at`, `updated_at`) VALUES
(6, 3, 1, '2025-05-05 15:20:16', '2025-05-05 15:20:16'),
(7, 3, 1, '2025-05-05 15:22:34', '2025-05-05 15:22:34'),
(8, 3, 1, '2025-05-07 17:40:25', '2025-05-07 17:40:25'),
(9, 3, 1, '2025-05-07 17:43:45', '2025-05-07 17:43:45'),
(10, 3, 1, '2025-05-09 11:06:35', '2025-05-09 11:06:35'),
(11, 3, 1, '2025-05-21 12:40:22', '2025-05-21 12:40:22'),
(12, 1, 1, '2025-05-21 12:56:05', '2025-05-21 12:56:05'),
(13, 3, 1, '2025-05-21 12:58:42', '2025-05-21 12:58:42'),
(14, 3, 1, '2025-05-21 12:59:57', '2025-05-21 12:59:57'),
(15, 3, 1, '2025-05-26 08:50:26', '2025-05-26 08:50:26'),
(16, 3, 13, '2025-05-26 11:27:10', '2025-05-26 11:27:10'),
(17, 3, 13, '2025-05-26 11:27:32', '2025-05-26 11:27:32'),
(18, 3, 1, '2025-05-26 11:33:17', '2025-05-26 11:33:17'),
(19, 1, 1, '2025-05-27 22:24:17', '2025-05-27 22:24:17'),
(20, 2, 1, '2025-06-07 13:14:34', '2025-06-07 13:14:34'),
(21, 2, 16, '2025-06-16 23:25:40', '2025-06-16 23:25:40'),
(22, 1, 18, '2025-06-16 23:39:37', '2025-06-16 23:39:37'),
(23, 1, 18, '2025-06-17 00:24:11', '2025-06-17 00:24:11'),
(24, 1, 18, '2025-06-17 01:18:35', '2025-06-17 01:18:35');

-- --------------------------------------------------------

--
-- Table structure for table `login_attempts_ip`
--

CREATE TABLE `login_attempts_ip` (
  `id` int(11) NOT NULL,
  `ip_address` varchar(45) NOT NULL,
  `failed_count` int(11) DEFAULT 0,
  `last_attempt` timestamp NOT NULL DEFAULT current_timestamp(),
  `blocked_until` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `mcer_level`
--

CREATE TABLE `mcer_level` (
  `pk_level` int(11) NOT NULL,
  `level_name` varchar(10) DEFAULT NULL,
  `level_desc` varchar(250) DEFAULT NULL,
  `created_at` datetime DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `mcer_level`
--

INSERT INTO `mcer_level` (`pk_level`, `level_name`, `level_desc`, `created_at`) VALUES
(1, 'A1', 'Principiante', '2025-04-19 15:12:14'),
(2, 'A2', 'Elemental', '2025-04-19 15:12:14'),
(3, 'B1', 'Intermedio', '2025-04-19 15:12:37'),
(4, 'B2', 'Intermedio-Avanzado', '2025-04-19 15:12:37'),
(5, 'C1', 'Avanzado', '2025-04-19 15:13:23'),
(6, 'C2', 'Experto', '2025-04-19 15:13:23');

-- --------------------------------------------------------

--
-- Table structure for table `password_reset_tokens`
--

CREATE TABLE `password_reset_tokens` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `token` varchar(255) NOT NULL,
  `expires_at` datetime NOT NULL,
  `created_at` datetime DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `prompts`
--

CREATE TABLE `prompts` (
  `pk_prompt` int(11) NOT NULL,
  `prompt_name` varchar(50) NOT NULL,
  `prompt_value` text NOT NULL,
  `status` varchar(10) NOT NULL DEFAULT 'ACTIVE',
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `prompts`
--

INSERT INTO `prompts` (`pk_prompt`, `prompt_name`, `prompt_value`, `status`, `created_at`, `updated_at`) VALUES
(1, 'Prompt 1', 'Hola soy un prompt', 'INACTIVE', '2025-04-20 14:47:45', '2025-04-20 15:27:52'),
(2, 'Prompt 1', 'Hola soy un prompt 2', 'INACTIVE', '2025-04-20 14:58:34', '2025-05-03 18:22:42'),
(3, 'Prompt 1', 'Hola soy un prompt 3', 'INACTIVE', '2025-04-20 14:58:58', '2025-04-20 15:10:52'),
(4, 'traducción', '-------test', 'INACTIVE', '2025-04-20 15:10:52', '2025-05-08 21:11:32'),
(5, 'Prompt Original', 'Asume el rol de un evaluador profesional de inglés especializado en el examen TOEIC. Tu tarea es analizar el desempeño de un estudiante en una prueba simulada de TOEIC, la cual contiene preguntas de las secciones READING y LISTENING. Debes realizar lo siguiente: 1. Evaluar el nivel general de inglés del estudiante según la escala MCER (A1, A2, B1, B2, C1, C2). 2. Calcular un puntaje estimado en el examen TOEIC (escala de 10 a 990 puntos). 3. Determinar si el estudiante ha aprobado la prueba considerando: - Universidades: entre 650 y 850 puntos. - Gobiernos: como en Japón, requieren un mínimo de 600 puntos. - Un puntaje menor a 600 debe considerarse como \'no aprobado\'. 4. Identificar fortalezas y debilidades basadas en las respuestas y nivel', 'INACTIVE', '2025-05-03 18:22:42', '2025-05-03 18:29:40'),
(6, 'Prompt Original', 'Asume el rol de un evaluador profesional de inglés especializado en el examen TOEIC. Tu tarea es analizar el desempeño de un estudiante en una prueba simulada de TOEIC, la cual contiene preguntas de las secciones READING y LISTENING. Debes realizar lo siguiente: 1. Evaluar el nivel general de inglés del estudiante según la escala MCER (A1, A2, B1, B2, C1, C2). 2. Calcular un puntaje estimado en el examen TOEIC (escala de 10 a 990 puntos). 3. Determinar si el estudiante ha aprobado la prueba considerando: - Universidades: entre 650 y 850 puntos. - Gobiernos: como en Japón, requieren un mínimo de 600 puntos. - Un puntaje menor a 600 debe considerarse como \'no aprobado\'. 4. Identificar fortalezas y debilidades basadas en las respuestas y niveles de dificultad. 5. Proporcionar recomendaciones claras para mejorar su rendimiento, enfocadas en TOEIC. 6. Basar el análisis en el número de respuestas correctas e incorrectas, así como el nivel MCER asignado a cada pregunta. FORMATO DE ENTRADA: El input SIEMPRE será un JSON con la clave \'exam_data\', que contiene una lista de bloques. Cada bloque representa un texto o audio con un conjunto de preguntas. Cada pregunta contiene: - question_text: el texto de la pregunta. - section: READING o LISTENING comprehension. - student_answer: la respuesta proporcionada por el estudiante. - is_correct: indica si fue respondida correctamente. - level: nivel MCER representado por la pregunta (ej. A2, B1). - title: el texto o contexto que se usó para las preguntas. - title_type: puede ser \'READING\' o \'LISTENING\'. - title_url: solo para LISTENING, puede ser null. Este es el formato fijo y no modificable del input: {\'exam_data\':[{\'questions\':[{\'is_correct\':false,\'level\':\'A2\',\'question_text\':\'When is the application deadline?\',\'section\':\'Reading comprehension\',\'student_answer\':\'June 15th\'},{\'is_correct\':true,\'level\':\'B1\',\'question_text\':\'What type of internships are being offered?\',\'section\':\'Reading comprehension\',\'student_answer\':\'Summer internships\'}],\'title\':\'We are offering summer internships for undergraduate students in the Marketing and IT departments. Apply before May 30th.\',\'title_type\':\'READING\',\'title_url\':null}]} Este es el formato fijo y no modificable del OUTPUT, en el caso de strengths, weaknesses y recommendations necesito que seas detallado: {\'mcer_level\':\'B1\',\'toeic_score\':720,\'passed\':true,\'strengths\':[\'Buena comprensión lectora en preguntas de nivel B1\',\'Respuestas correctas en temas de vocabulario profesional\'],\'weaknesses\':[\'Errores frecuentes en preguntas de nivel A2\',\'Confusión con fechas y detalles específicos\'],\'recommendations\':[\'Reforzar comprensión de detalles en textos breves\',\'Practicar ejercicios de listening enfocados en conversaciones cotidianas\',\'Ampliar vocabulario relacionado a contextos laborales\']}', 'INACTIVE', '2025-05-03 18:29:40', '2025-05-03 18:48:21'),
(7, 'Prompt Original', 'Asume el rol de un evaluador profesional de inglés especializado en el examen TOEIC. Tu tarea es analizar el desempeño de un estudiante en una prueba simulada de TOEIC, la cual contiene preguntas de las secciones READING y LISTENING. Debes realizar lo siguiente: 1. Evaluar el nivel general de inglés del estudiante según la escala MCER (A1, A2, B1, B2, C1, C2). 2. Calcular un puntaje estimado en el examen TOEIC (escala de 10 a 990 puntos). 3. Determinar si el estudiante ha aprobado la prueba considerando: - Universidades: entre 650 y 850 puntos. - Gobiernos: como en Japón, requieren un mínimo de 600 puntos. - Un puntaje menor a 600 debe considerarse como \'no aprobado\'. 4. Identificar fortalezas y debilidades basadas en las respuestas y niveles de dificultad. 5. Proporcionar recomendaciones claras para mejorar su rendimiento, enfocadas en TOEIC. 6. Basar el análisis en el número de respuestas correctas e incorrectas, así como el nivel MCER asignado a cada pregunta. FORMATO DE ENTRADA: El input SIEMPRE será un JSON con la clave \'exam_data\', que contiene una lista de bloques. Cada bloque representa un texto o audio con un conjunto de preguntas. Cada pregunta contiene: - question_text: el texto de la pregunta. - section: READING o LISTENING comprehension. - student_answer: la respuesta proporcionada por el estudiante. - is_correct: indica si fue respondida correctamente. - level: nivel MCER representado por la pregunta (ej. A2, B1). - title: el texto o contexto que se usó para las preguntas. - title_type: puede ser \'READING\' o \'LISTENING\'. - title_url: solo para LISTENING, puede ser null. Este es el formato fijo y no modificable del input: {\'exam_data\':[{\'questions\':[{\'is_correct\':false,\'level\':\'A2\',\'question_text\':\'When is the application deadline?\',\'section\':\'Reading comprehension\',\'student_answer\':\'June 15th\'},{\'is_correct\':true,\'level\':\'B1\',\'question_text\':\'What type of internships are being offered?\',\'section\':\'Reading comprehension\',\'student_answer\':\'Summer internships\'}],\'title\':\'We are offering summer internships for undergraduate students in the Marketing and IT departments. Apply before May 30th.\',\'title_type\':\'READING\',\'title_url\':null}]} Este es el formato fijo y no modificable del OUTPUT, en el caso de strengths, weaknesses y recommendations necesito que seas detallado enfocandote en casos especificos de las respuestas del estudiante: {\'mcer_level\':\'B1\',\'toeic_score\':720,\'passed\':true,\'strengths\':[\'Buena comprensión lectora en preguntas de nivel B1\',\'Respuestas correctas en temas de vocabulario profesional\'],\'weaknesses\':[\'Errores frecuentes en preguntas de nivel A2\',\'Confusión con fechas y detalles específicos\'],\'recommendations\':[\'Reforzar comprensión de detalles en textos breves\',\'Practicar ejercicios de listening enfocados en conversaciones cotidianas\',\'Ampliar vocabulario relacionado a contextos laborales\']}', 'INACTIVE', '2025-05-03 18:48:21', '2025-05-03 19:18:05'),
(8, 'Prompt Original', 'Asume el rol de un evaluador profesional de inglés especializado en el examen TOEIC. Tu tarea es analizar el desempeño de un estudiante en una prueba simulada de TOEIC, la cual contiene preguntas de las secciones READING y LISTENING. Debes realizar lo siguiente: 1. Evaluar el nivel general de inglés del estudiante según la escala MCER (A1, A2, B1, B2, C1, C2). 2. Calcular un puntaje estimado en el examen TOEIC (escala de 10 a 990 puntos). 3. Determinar si el estudiante ha aprobado la prueba considerando: entre 650 y 850 puntos. - Un puntaje menor a 650 debe considerarse como \'no aprobado\'. 4. Identificar fortalezas y debilidades bastante detalladas basadas en las respuestas y niveles de dificultad. 5. Proporcionar recomendaciones claras y extensas para mejorar su rendimiento, enfocadas en TOEIC. 6. Basar el análisis en el número de respuestas correctas e incorrectas, así como el nivel MCER asignado a cada pregunta. FORMATO DE ENTRADA: El input SIEMPRE será un JSON con la clave \'exam_data\', que contiene una lista de bloques. Cada bloque representa un texto o audio con un conjunto de preguntas. Cada pregunta contiene: - question_text: el texto de la pregunta. - section: READING o LISTENING comprehension. - student_answer: la respuesta proporcionada por el estudiante. - is_correct: indica si fue respondida correctamente. - level: nivel MCER representado por la pregunta (ej. A2, B1). - title: el texto o contexto que se usó para las preguntas. - title_type: puede ser \'READING\' o \'LISTENING\'. - title_url: solo para LISTENING, puede ser null. Este es el formato fijo y no modificable del input: {\'exam_data\':[{\'questions\':[{\'is_correct\':false,\'level\':\'A2\',\'question_text\':\'When is the application deadline?\',\'section\':\'Reading comprehension\',\'student_answer\':\'June 15th\'},{\'is_correct\':true,\'level\':\'B1\',\'question_text\':\'What type of internships are being offered?\',\'section\':\'Reading comprehension\',\'student_answer\':\'Summer internships\'}],\'title\':\'We are offering summer internships for undergraduate students in the Marketing and IT departments. Apply before May 30th.\',\'title_type\':\'READING\',\'title_url\':null}]} Este es el formato fijo y no modificable del OUTPUT, en el caso de strengths, weaknesses y recommendations necesito que seas detallado enfocandote en casos especificos de las respuestas del estudiante: {\'mcer_level\':\'B1\',\'toeic_score\':720,\'passed\':true,\'strengths\':[\'aqui ran las fortalezas del estudiante en un parrafo\'],\'weaknesses\':[\'aqui ran las debilidades del estudiante en un parrafo\'],\'recommendations\':[\'aqui ira las recomendaciones para el estudiante en un parrafo\']}', 'ACTIVE', '2025-05-03 19:18:05', '2025-05-08 21:12:18'),
(9, '---- test 2', 'es un test', 'INACTIVE', '2025-05-08 21:11:56', '2025-05-08 21:12:03'),
(10, '---- test 2', 'es un test mas ', 'INACTIVE', '2025-05-08 21:12:10', '2025-05-08 21:12:18');

-- --------------------------------------------------------

--
-- Table structure for table `questions`
--

CREATE TABLE `questions` (
  `pk_question` int(11) NOT NULL,
  `toeic_section_fk` int(11) NOT NULL,
  `question_text` text DEFAULT NULL,
  `title_fk` int(11) NOT NULL,
  `level_fk` int(11) NOT NULL,
  `status` varchar(10) NOT NULL DEFAULT 'ACTIVE',
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `questions`
--

INSERT INTO `questions` (`pk_question`, `toeic_section_fk`, `question_text`, `title_fk`, `level_fk`, `status`, `created_at`, `updated_at`) VALUES
(1, 3, 'What is the main objective of the message?', 1, 4, 'ACTIVE', '2025-04-19 15:22:28', '2025-04-19 16:33:59'),
(2, 3, 'What can be implied about the workshop?', 1, 4, 'ACTIVE', '2025-04-19 15:34:27', '2025-04-20 11:33:44'),
(3, 3, 'What can be implied about Dr Friedman?', 1, 4, 'ACTIVE', '2025-04-19 15:37:34', '2025-04-19 16:33:59'),
(4, 3, 'What has happened to the address list?', 1, 4, 'ACTIVE', '2025-04-19 15:42:28', '2025-04-19 16:33:59'),
(5, 1, 'Hi, my ____ is Diego', 2, 3, 'ACTIVE', '2025-04-19 16:38:27', '2025-04-19 18:09:54'),
(6, 1, 'All the orders got _________ on schedule.', 2, 4, 'ACTIVE', '2025-04-19 16:55:24', '2025-04-19 16:55:24'),
(7, 1, 'She has been working here _______ five years.', 2, 3, 'ACTIVE', '2025-04-19 16:55:24', '2025-04-19 16:55:24'),
(8, 1, 'She _______ lunch when the phone rang.', 2, 4, 'ACTIVE', '2025-04-19 16:55:24', '2025-04-19 16:55:24'),
(9, 7, 'What size coffee does the customer order?', 3, 3, 'ACTIVE', '2025-05-01 15:18:09', '2025-05-01 15:18:09'),
(10, 7, 'How does the customer want their coffee?', 3, 3, 'ACTIVE', '2025-05-01 15:18:09', '2025-05-01 15:18:09'),
(11, 7, 'Where does this conversation most likely take place?', 3, 3, 'ACTIVE', '2025-05-01 15:18:09', '2025-05-01 15:18:09'),
(12, 7, 'What does the barista offer the customer?', 3, 3, 'ACTIVE', '2025-05-01 15:18:09', '2025-05-01 15:18:09'),
(13, 7, 'What did Speaker B do with the report?', 4, 3, 'ACTIVE', '2025-05-01 15:18:36', '2025-05-01 15:18:36'),
(14, 7, 'When is the meeting?', 4, 3, 'ACTIVE', '2025-05-01 15:18:36', '2025-05-01 15:18:36'),
(15, 7, 'Where does this conversation most likely take place?', 4, 3, 'ACTIVE', '2025-05-01 15:18:36', '2025-05-01 15:18:36'),
(16, 7, 'What is the purpose of the report?', 4, 3, 'ACTIVE', '2025-05-01 15:18:36', '2025-05-01 15:18:36'),
(17, 7, 'What food does the customer order?', 5, 3, 'ACTIVE', '2025-05-01 15:18:51', '2025-05-01 15:18:51'),
(18, 7, 'What drink does the customer order?', 5, 3, 'ACTIVE', '2025-05-01 15:18:51', '2025-05-01 15:18:51'),
(19, 7, 'Where does this conversation most likely take place?', 5, 3, 'ACTIVE', '2025-05-01 15:18:51', '2025-05-01 15:18:51'),
(20, 7, 'What does the server ask the customer?', 5, 3, 'ACTIVE', '2025-05-01 15:18:51', '2025-05-01 15:18:51'),
(21, 7, 'What are the patient\'s symptoms?', 6, 3, 'ACTIVE', '2025-05-01 15:19:13', '2025-05-01 15:19:13'),
(22, 7, 'Who is Speaker A likely to be?', 6, 3, 'ACTIVE', '2025-05-01 15:19:13', '2025-05-01 15:19:13'),
(23, 7, 'Where does this conversation take place?', 6, 3, 'ACTIVE', '2025-05-01 15:19:13', '2025-05-01 15:19:13'),
(24, 7, 'What does Speaker A say they will do next?', 6, 3, 'ACTIVE', '2025-05-01 15:19:13', '2025-05-01 15:19:13'),
(25, 7, 'Where is Speaker B planning to visit?', 7, 3, 'ACTIVE', '2025-05-01 15:19:30', '2025-05-01 15:19:30'),
(26, 7, 'When is Speaker B planning to travel?', 7, 3, 'ACTIVE', '2025-05-01 15:19:30', '2025-05-01 15:19:30'),
(27, 7, 'How does Speaker A feel about the plans?', 7, 3, 'ACTIVE', '2025-05-01 15:19:30', '2025-05-01 15:19:30'),
(28, 7, 'What is the main topic of this conversation?', 7, 3, 'ACTIVE', '2025-05-01 15:19:30', '2025-05-01 15:19:30'),
(29, 7, 'Who is calling Anna?', 8, 2, 'ACTIVE', '2025-05-01 15:23:10', '2025-05-01 15:23:10'),
(30, 7, 'What department does John work in?', 8, 2, 'ACTIVE', '2025-05-01 15:23:10', '2025-05-01 15:23:10'),
(31, 7, 'How does Anna answer the phone?', 8, 3, 'ACTIVE', '2025-05-01 15:23:10', '2025-05-01 15:23:10'),
(32, 7, 'What is the purpose of the call?', 8, 3, 'ACTIVE', '2025-05-01 15:23:10', '2025-05-01 15:23:10'),
(33, 7, 'What type of room does the guest want?', 9, 2, 'ACTIVE', '2025-05-01 15:23:21', '2025-05-01 15:23:21'),
(34, 7, 'How many nights does the guest want to stay?', 9, 2, 'ACTIVE', '2025-05-01 15:23:21', '2025-05-01 15:23:21'),
(35, 7, 'What does the receptionist ask about?', 9, 3, 'ACTIVE', '2025-05-01 15:23:21', '2025-05-01 15:23:21'),
(36, 7, 'What is the guest doing?', 9, 3, 'ACTIVE', '2025-05-01 15:23:21', '2025-05-01 15:23:21'),
(37, 7, 'How many people is the reservation for?', 10, 2, 'ACTIVE', '2025-05-01 15:23:33', '2025-05-01 15:23:33'),
(38, 7, 'What time is the reservation for?', 10, 2, 'ACTIVE', '2025-05-01 15:23:33', '2025-05-01 15:23:33'),
(39, 7, 'What does the restaurant staff ask?', 10, 3, 'ACTIVE', '2025-05-01 15:23:33', '2025-05-01 15:23:33'),
(40, 7, 'What is the customer doing?', 10, 3, 'ACTIVE', '2025-05-01 15:23:33', '2025-05-01 15:23:33'),
(41, 7, 'Where does the speaker want to go?', 11, 2, 'ACTIVE', '2025-05-01 15:23:48', '2025-05-01 15:23:48'),
(42, 7, 'What are the directions given?', 11, 2, 'ACTIVE', '2025-05-01 15:23:48', '2025-05-01 15:23:48'),
(43, 7, 'How does the speaker respond to the directions?', 11, 3, 'ACTIVE', '2025-05-01 15:23:49', '2025-05-01 15:23:49'),
(44, 7, 'What is the relationship between the speakers?', 11, 3, 'ACTIVE', '2025-05-01 15:23:49', '2025-05-01 15:23:49'),
(45, 7, 'What position did the interviewee hold in their last job?', 12, 3, 'ACTIVE', '2025-05-01 15:24:01', '2025-05-01 15:24:01'),
(46, 7, 'How does the interviewer respond to the answer?', 12, 3, 'ACTIVE', '2025-05-01 15:24:01', '2025-05-01 15:24:01'),
(47, 7, 'What is the interviewer asking about?', 12, 3, 'ACTIVE', '2025-05-01 15:24:01', '2025-05-01 15:24:01'),
(48, 7, 'What is the likely setting of this conversation?', 12, 3, 'ACTIVE', '2025-05-01 15:24:01', '2025-05-01 15:24:01'),
(49, 7, 'What is the weather like today?', 13, 2, 'ACTIVE', '2025-05-01 15:27:47', '2025-05-01 15:27:47'),
(50, 7, 'How does Speaker B feel about the weather?', 13, 2, 'ACTIVE', '2025-05-01 15:27:47', '2025-05-01 15:27:47'),
(51, 7, 'What do they hope for tomorrow?', 13, 2, 'ACTIVE', '2025-05-01 15:27:47', '2025-05-01 15:27:47'),
(52, 7, 'How long has it been raining?', 13, 2, 'ACTIVE', '2025-05-01 15:27:47', '2025-05-01 15:27:47'),
(53, 7, 'What size is Speaker A looking for?', 14, 2, 'ACTIVE', '2025-05-01 15:28:00', '2025-05-01 15:28:00'),
(54, 7, 'What does Speaker B do in response?', 14, 2, 'ACTIVE', '2025-05-01 15:28:00', '2025-05-01 15:28:00'),
(55, 7, 'How does Speaker A respond at the end?', 14, 2, 'ACTIVE', '2025-05-01 15:28:00', '2025-05-01 15:28:00'),
(56, 7, 'Where is this conversation most likely taking place?', 14, 2, 'ACTIVE', '2025-05-01 15:28:00', '2025-05-01 15:28:00'),
(57, 7, 'What is Speaker A looking for?', 15, 2, 'ACTIVE', '2025-05-01 15:28:12', '2025-05-01 15:28:12'),
(58, 7, 'Where are the science books located?', 15, 2, 'ACTIVE', '2025-05-01 15:28:12', '2025-05-01 15:28:12'),
(59, 7, 'How does Speaker A respond to the information?', 15, 2, 'ACTIVE', '2025-05-01 15:28:12', '2025-05-01 15:28:12'),
(60, 7, 'Where is this conversation taking place?', 15, 2, 'ACTIVE', '2025-05-01 15:28:12', '2025-05-01 15:28:12'),
(61, 3, 'What is the purpose of this email?', 16, 3, 'ACTIVE', '2025-05-01 15:28:28', '2025-05-01 15:28:28'),
(62, 3, 'What will the meeting be about?', 16, 3, 'ACTIVE', '2025-05-01 15:28:28', '2025-05-01 15:28:28'),
(63, 3, 'When does the sender want to meet?', 16, 3, 'ACTIVE', '2025-05-01 15:28:28', '2025-05-01 15:28:28'),
(64, 3, 'How does the email begin?', 16, 3, 'ACTIVE', '2025-05-01 15:28:28', '2025-05-01 15:28:28'),
(65, 3, 'What is the purpose of this letter?', 17, 3, 'ACTIVE', '2025-05-01 15:28:42', '2025-05-01 15:28:42'),
(66, 3, 'What position is the applicant applying for?', 17, 3, 'ACTIVE', '2025-05-01 15:28:42', '2025-05-01 15:28:42'),
(67, 3, 'How is the letter addressed?', 17, 3, 'ACTIVE', '2025-05-01 15:28:42', '2025-05-01 15:28:42'),
(68, 3, 'What type of document is this?', 17, 3, 'ACTIVE', '2025-05-01 15:28:42', '2025-05-01 15:28:42'),
(69, 3, 'What did the author visit last week?', 18, 2, 'ACTIVE', '2025-05-01 15:33:47', '2025-05-01 15:33:47'),
(70, 3, 'What did the author especially love about Rome?', 18, 2, 'ACTIVE', '2025-05-01 15:33:47', '2025-05-01 15:33:47'),
(71, 3, 'How would you describe the city of Rome based on the text?', 18, 3, 'ACTIVE', '2025-05-01 15:33:47', '2025-05-01 15:33:47'),
(72, 3, 'What type of text is this?', 18, 1, 'ACTIVE', '2025-05-01 15:33:47', '2025-05-01 15:33:47'),
(73, 3, 'What is the purpose of this text?', 19, 2, 'ACTIVE', '2025-05-01 15:34:00', '2025-05-01 15:34:00'),
(74, 3, 'When will the workshop be held?', 19, 1, 'ACTIVE', '2025-05-01 15:34:00', '2025-05-01 15:34:00'),
(75, 3, 'What is the topic of the workshop?', 19, 2, 'ACTIVE', '2025-05-01 15:34:01', '2025-05-01 15:34:01'),
(76, 3, 'Where will the workshop take place?', 19, 1, 'ACTIVE', '2025-05-01 15:34:01', '2025-05-01 15:34:01'),
(77, 3, 'Who is required to complete the training?', 20, 1, 'ACTIVE', '2025-05-01 15:34:14', '2025-05-01 15:34:14'),
(78, 3, 'What type of training is mentioned?', 20, 1, 'ACTIVE', '2025-05-01 15:34:15', '2025-05-01 15:34:15'),
(79, 3, 'When must the training be completed?', 20, 1, 'ACTIVE', '2025-05-01 15:34:15', '2025-05-01 15:34:15'),
(80, 3, 'What type of document is this?', 20, 2, 'ACTIVE', '2025-05-01 15:34:15', '2025-05-01 15:34:15'),
(81, 3, 'What product is being described?', 21, 1, 'ACTIVE', '2025-05-01 15:34:27', '2025-05-01 15:34:27'),
(82, 3, 'What feature is NOT mentioned in the description?', 21, 3, 'ACTIVE', '2025-05-01 15:34:27', '2025-05-01 15:34:27'),
(83, 3, 'How would you describe the design of the product?', 21, 2, 'ACTIVE', '2025-05-01 15:34:28', '2025-05-01 15:34:28'),
(84, 3, 'What is special about the battery?', 21, 2, 'ACTIVE', '2025-05-01 15:34:28', '2025-05-01 15:34:28'),
(85, 3, 'Who announced the project?', 22, 1, 'ACTIVE', '2025-05-01 15:34:40', '2025-05-01 15:34:40'),
(86, 3, 'What is the project about?', 22, 1, 'ACTIVE', '2025-05-01 15:34:40', '2025-05-01 15:34:40'),
(87, 3, 'When will the project start?', 22, 1, 'ACTIVE', '2025-05-01 15:34:40', '2025-05-01 15:34:40'),
(88, 3, 'What type of text is this?', 22, 2, 'ACTIVE', '2025-05-01 15:34:40', '2025-05-01 15:34:40'),
(89, 3, 'What is the first step to install the software?', 23, 3, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(90, 3, 'How should you interact with the setup file?', 23, 3, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(91, 3, 'What will guide you during the installation process?', 23, 3, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(92, 3, 'What type of document is this text most likely from?', 23, 3, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(93, 3, 'What was positive about the hotel according to the review?', 24, 3, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(94, 3, 'What aspect could have been better?', 24, 3, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(95, 3, 'How would you describe the hotel\'s location?', 24, 3, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(96, 3, 'What type of text is this?', 24, 3, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(97, 3, 'What is the user trying to do according to the FAQ?', 25, 3, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(98, 3, 'Where should the user click to reset the password?', 25, 3, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(99, 3, 'What should the user do after clicking \"Forgot Password\"?', 25, 3, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(100, 3, 'What type of document is this text from?', 25, 3, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(101, 3, 'What is the purpose of this message?', 26, 3, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(102, 3, 'When is the appointment scheduled?', 26, 3, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(103, 3, 'What type of appointment is mentioned?', 26, 3, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(104, 3, 'How would you describe the tone of this message?', 26, 3, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(105, 3, 'What was the weather like at the beginning of the story?', 27, 3, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(106, 3, 'Who is the main character mentioned?', 27, 3, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(107, 3, 'What unexpected event happened?', 27, 3, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(108, 3, 'What type of text is this?', 27, 3, 'ACTIVE', '2025-05-01 15:38:30', '2025-05-01 15:38:30'),
(109, 3, 'Why will the National Art Museum be closed on Monday?', 41, 3, 'ACTIVE', '2025-05-01 16:15:11', '2025-05-01 16:15:11'),
(110, 3, 'What is today\'s weather forecast?', 44, 2, 'ACTIVE', '2025-05-01 16:21:14', '2025-05-01 16:21:14'),
(111, 3, 'What is the expected high temperature?', 44, 1, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(112, 3, 'When might there be light showers?', 44, 2, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(113, 3, 'What type of precipitation is expected?', 44, 2, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(114, 3, 'What should you use in case of fire?', 45, 1, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(115, 3, 'What should you avoid during a fire?', 45, 1, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(116, 3, 'How should you evacuate the building?', 45, 2, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(117, 3, 'What is the main purpose of these instructions?', 45, 3, 'ACTIVE', '2025-05-01 16:21:15', '2025-05-01 16:21:15'),
(118, 3, 'What departments are offering summer internships?', 46, 2, 'ACTIVE', '2025-05-01 16:26:05', '2025-05-01 16:26:05'),
(119, 3, 'When is the application deadline?', 46, 2, 'ACTIVE', '2025-05-01 16:26:05', '2025-05-01 16:26:05'),
(120, 3, 'Who can apply for these internships?', 46, 2, 'ACTIVE', '2025-05-01 16:26:05', '2025-05-01 16:26:05'),
(121, 3, 'What type of internships are being offered?', 46, 3, 'ACTIVE', '2025-05-01 16:26:05', '2025-05-01 16:26:05'),
(122, 3, 'How many ingredients does this pasta recipe require?', 47, 1, 'ACTIVE', '2025-05-01 16:26:18', '2025-05-01 16:26:18'),
(123, 3, 'How long does it take to prepare this recipe?', 47, 1, 'ACTIVE', '2025-05-01 16:26:18', '2025-05-01 16:26:18'),
(124, 3, 'What type of recipe is being introduced?', 47, 1, 'ACTIVE', '2025-05-01 16:26:18', '2025-05-01 16:26:18'),
(125, 3, 'How would you describe this recipe?', 47, 2, 'ACTIVE', '2025-05-01 16:26:18', '2025-05-01 16:26:18'),
(126, 3, 'Where is parking prohibited according to the notice?', 48, 3, 'ACTIVE', '2025-05-01 16:26:43', '2025-05-01 16:26:43'),
(127, 3, 'What will happen to unauthorized vehicles?', 48, 3, 'ACTIVE', '2025-05-01 16:26:43', '2025-05-01 16:26:43'),
(128, 3, 'Who will pay for the towing expenses?', 48, 4, 'ACTIVE', '2025-05-01 16:26:43', '2025-05-01 16:26:43'),
(129, 3, 'What is the main purpose of this notice?', 48, 4, 'ACTIVE', '2025-05-01 16:26:43', '2025-05-01 16:26:43'),
(130, 3, 'When will the keynote speech begin?', 49, 3, 'ACTIVE', '2025-05-01 16:26:54', '2025-05-01 16:26:54'),
(131, 3, 'What will follow the keynote speech?', 49, 3, 'ACTIVE', '2025-05-01 16:26:54', '2025-05-01 16:26:54'),
(132, 3, 'What topics will the breakout sessions cover?', 49, 4, 'ACTIVE', '2025-05-01 16:26:54', '2025-05-01 16:26:54'),
(133, 3, 'What type of event is being described?', 49, 3, 'ACTIVE', '2025-05-01 16:26:55', '2025-05-01 16:26:55'),
(134, 3, 'When does the training session start?', 50, 2, 'ACTIVE', '2025-05-01 16:27:07', '2025-05-01 16:27:07'),
(135, 3, 'Where will the training take place?', 50, 2, 'ACTIVE', '2025-05-01 16:27:07', '2025-05-01 16:27:07'),
(136, 3, 'What should participants bring?', 50, 2, 'ACTIVE', '2025-05-01 16:27:07', '2025-05-01 16:27:07'),
(137, 3, 'What is the purpose of this email?', 50, 3, 'ACTIVE', '2025-05-01 16:27:07', '2025-05-01 16:27:07'),
(138, 3, 'What is the main recommendation in the environmental tip?', 51, 2, 'ACTIVE', '2025-05-01 16:32:19', '2025-05-01 16:32:19'),
(139, 3, 'What kind of impact do small changes have according to the tip?', 51, 2, 'ACTIVE', '2025-05-01 16:32:19', '2025-05-01 16:32:19'),
(140, 3, 'Where is the reusable bag recommendation most applicable?', 51, 1, 'ACTIVE', '2025-05-01 16:32:19', '2025-05-01 16:32:19'),
(141, 3, 'What is the purpose of the environmental tip?', 51, 2, 'ACTIVE', '2025-05-01 16:32:19', '2025-05-01 16:32:19'),
(142, 3, 'What item was lost?', 52, 1, 'ACTIVE', '2025-05-01 16:32:37', '2025-05-01 16:32:37'),
(143, 3, 'Where was the item lost?', 52, 1, 'ACTIVE', '2025-05-01 16:32:37', '2025-05-01 16:32:37'),
(144, 3, 'What should you do if you find the item?', 52, 2, 'ACTIVE', '2025-05-01 16:32:37', '2025-05-01 16:32:37'),
(145, 3, 'What is offered for returning the lost item?', 52, 2, 'ACTIVE', '2025-05-01 16:32:37', '2025-05-01 16:32:37'),
(146, 7, 'What is SPEAKER_B doing?', 28, 2, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(147, 7, 'What does SPEAKER_A remind SPEAKER_B about?', 28, 2, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(148, 7, 'Where are the speakers likely going?', 28, 3, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(149, 7, 'What time of day is this conversation taking place?', 28, 1, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(150, 7, 'What is the main topic of the conversation?', 29, 3, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(151, 7, 'What does SPEAKER_B need to do?', 29, 2, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(152, 7, 'By when should the assignment be submitted?', 29, 4, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(153, 7, 'Where is this conversation most likely taking place?', 29, 3, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(154, 7, 'What does SPEAKER_A want to do?', 30, 2, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(155, 7, 'What does SPEAKER_B ask for?', 30, 3, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(156, 7, 'Where does this conversation take place?', 30, 1, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(157, 7, 'What does SPEAKER_A provide?', 30, 4, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(158, 7, 'Where is this conversation taking place?', 31, 2, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(159, 7, 'What does SPEAKER_A ask for?', 31, 3, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(160, 7, 'What does SPEAKER_A say at the end?', 31, 1, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(161, 7, 'What is SPEAKER_B most likely doing?', 31, 4, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(162, 7, 'What happened to the person mentioned?', 32, 3, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(163, 7, 'What was the person doing when it happened?', 32, 4, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(164, 7, 'What does SPEAKER_B suggest doing?', 32, 2, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(165, 7, 'What is the relationship between the speakers?', 32, 3, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(166, 7, 'What is SPEAKER_A\'s problem?', 33, 2, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(167, 7, 'What does SPEAKER_B offer to do?', 33, 3, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(168, 7, 'What is SPEAKER_A\'s response to the offer?', 33, 4, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(169, 7, 'What is the most likely relationship between the speakers?', 33, 3, 'ACTIVE', '2025-05-01 16:33:33', '2025-05-01 16:33:33'),
(170, 7, 'What type of car does the customer prefer?', 34, 3, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(171, 7, 'How long does the customer need the car?', 34, 2, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(172, 7, 'What is the first speaker requesting?', 34, 3, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(173, 7, 'What does the second speaker ask about?', 34, 2, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(174, 7, 'What does the interviewer ask about?', 35, 3, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(175, 7, 'How does the interviewer respond to the answer?', 35, 3, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(176, 7, 'What does the candidate aspire to do?', 35, 4, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(177, 7, 'What time frame is mentioned in the question?', 35, 2, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(178, 7, 'What is the parent asking about?', 36, 3, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(179, 7, 'How does the teacher describe the student?', 36, 3, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(180, 7, 'What does the parent promise to do?', 36, 4, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(181, 7, 'What is the student\'s name?', 36, 2, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(182, 7, 'Where did the speaker lose their item?', 37, 3, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(183, 7, 'What item was lost?', 37, 2, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(184, 7, 'What is the color of the lost item?', 37, 2, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(185, 7, 'What was inside the lost item?', 37, 3, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(186, 7, 'What are the speakers discussing?', 38, 3, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(187, 7, 'How will the second speaker send the information?', 38, 3, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(188, 7, 'What does the first speaker say at the end?', 38, 2, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(189, 7, 'What is the tone of the conversation?', 38, 4, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(190, 7, 'What does the first speaker want to obtain?', 39, 2, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(191, 7, 'What does the second speaker ask the first to do?', 39, 3, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(192, 7, 'How does the first speaker respond to the request?', 39, 3, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(193, 7, 'Where is this conversation most likely taking place?', 39, 4, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(194, 7, 'What item is specifically mentioned?', 40, 2, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(195, 7, 'Where are the mentioned items already placed?', 40, 3, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(196, 7, 'What do the speakers decide to do next?', 40, 3, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-01 16:35:01'),
(197, 3, 'What is the relationship between the speakers?', 100, 4, 'ACTIVE', '2025-05-01 16:35:01', '2025-05-08 21:46:49');

-- --------------------------------------------------------

--
-- Table structure for table `questions_titles`
--

CREATE TABLE `questions_titles` (
  `pk_title` int(11) NOT NULL,
  `title_name` varchar(100) NOT NULL,
  `title_test` text NOT NULL,
  `title_type` varchar(20) NOT NULL,
  `title_url` varchar(255) DEFAULT NULL,
  `status` varchar(10) NOT NULL DEFAULT 'ACTIVE',
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `questions_titles`
--

INSERT INTO `questions_titles` (`pk_title`, `title_name`, `title_test`, `title_type`, `title_url`, `status`, `created_at`, `updated_at`) VALUES
(1, 'Dear Helen - Workshop Feedback', 'Dear Helen,\n\nI would like to congratulate you on organising such an excellent and informative workshop. I know a lot of people learnt a great deal from it. Can you pass on my thanks to Doctor Friedman for his fascinating talk on Staff Motivation? I realise how lucky we were that he was able to find the time for us. The feedback from the staff was very positive. Let’s hope we actually see an improvement in staff motivation as a result!\n\nBy the way, I’m missing my list of addresses of the delegates who attended. Did I happen to leave it in your office? It’s just that I haven’t seen it since our meeting on Friday.\n\nThanks again for a great day,\nAnne', 'READING', NULL, 'ACTIVE', '2025-04-19 12:47:13', '2025-04-19 16:33:59'),
(2, 'Dear Helen - Workshop Feedback', 'Dear Helen,\n\nI would like to congratulate you on organising such an excellent and informative workshop. I know a lot of people learnt a great deal from it. Can you pass on my thanks to Doctor Friedman for his fascinating talk on Staff Motivation? I realise how lucky we were that he was able to find the time for us. The feedback from the staff was very positive. Let’s hope we actually see an improvement in staff motivation as a result!\n\nBy the way, I’m missing my list of addresses of the delegates who attended. Did I happen to leave it in your office? It’s just that I haven’t seen it since our meeting on Friday.\n\nThanks again for a great day,\nAnne', 'READING', NULL, 'ACTIVE', '2025-04-19 14:46:19', '2025-05-28 21:24:34'),
(3, 'Daily Conversation - Coffee Shop', '[SPEAKER_A] Hi, can I get a large coffee?\n[SPEAKER_B] Sure, do you want cream or sugar?\n[SPEAKER_A] Just black, please.', 'LISTENING', 'https://example.com/audio1.mp3', 'ACTIVE', '2025-05-01 13:41:26', '2025-05-01 13:41:26'),
(4, 'Office Meeting', '[SPEAKER_A] Did you get the report?\n[SPEAKER_B] Yes, I sent it yesterday.\n[SPEAKER_A] Great, we need it for today\'s meeting.', 'LISTENING', 'https://example.com/audio2.mp3', 'ACTIVE', '2025-05-01 13:41:26', '2025-05-01 13:41:26'),
(5, 'Ordering Food', '[SPEAKER_A] I\'d like a cheeseburger and fries.\n[SPEAKER_B] Would you like a drink with that?\n[SPEAKER_A] Yes, a soda please.', 'LISTENING', 'https://example.com/audio3.mp3', 'ACTIVE', '2025-05-01 13:41:26', '2025-05-01 13:41:26'),
(6, 'Doctor Appointment', '[SPEAKER_A] What brings you in today?\n[SPEAKER_B] I have a sore throat and a fever.\n[SPEAKER_A] Let\'s take a look.', 'LISTENING', 'https://example.com/audio4.mp3', 'ACTIVE', '2025-05-01 13:41:26', '2025-05-01 13:41:26'),
(7, 'Travel Plans', '[SPEAKER_A] Are you going anywhere this summer?\n[SPEAKER_B] Yes, I\'m visiting Spain.\n[SPEAKER_A] That sounds exciting!', 'LISTENING', 'https://example.com/audio5.mp3', 'ACTIVE', '2025-05-01 13:41:26', '2025-05-01 13:41:26'),
(8, 'Phone Call', '[SPEAKER_A] Hello, is this Anna?\n[SPEAKER_B] Yes, speaking.\n[SPEAKER_A] This is John from HR.', 'LISTENING', 'https://example.com/audio6.mp3', 'ACTIVE', '2025-05-01 13:41:26', '2025-05-01 13:41:26'),
(9, 'Hotel Booking', '[SPEAKER_A] I\'d like to book a room for two nights.\n[SPEAKER_B] Certainly. Do you prefer a single or double?\n[SPEAKER_A] A double, please.', 'LISTENING', 'https://example.com/audio7.mp3', 'ACTIVE', '2025-05-01 13:41:26', '2025-05-01 13:41:26'),
(10, 'Restaurant Reservation', '[SPEAKER_A] I want to reserve a table for four.\n[SPEAKER_B] What time would you like?\n[SPEAKER_A] At 7 PM, please.', 'LISTENING', 'https://example.com/audio8.mp3', 'ACTIVE', '2025-05-01 13:41:26', '2025-05-01 13:41:26'),
(11, 'Asking for Directions', '[SPEAKER_A] How do I get to the train station?\n[SPEAKER_B] Go straight and take the second right.\n[SPEAKER_A] Thanks a lot.', 'LISTENING', 'https://example.com/audio9.mp3', 'ACTIVE', '2025-05-01 13:41:26', '2025-05-01 13:41:26'),
(12, 'Interview', '[SPEAKER_A] Tell me about your last job.\n[SPEAKER_B] I worked as a project manager.\n[SPEAKER_A] That\'s impressive.', 'LISTENING', 'https://example.com/audio10.mp3', 'ACTIVE', '2025-05-01 13:41:26', '2025-05-01 13:41:26'),
(13, 'Weather Chat', '[SPEAKER_A] It\'s been raining all day!\n[SPEAKER_B] I know, I miss the sun.\n[SPEAKER_A] Let\'s hope tomorrow is better.', 'LISTENING', 'https://example.com/audio11.mp3', 'ACTIVE', '2025-05-01 13:41:26', '2025-05-01 13:41:26'),
(14, 'Shopping', '[SPEAKER_A] Do you have this in a medium?\n[SPEAKER_B] Let me check the back.\n[SPEAKER_A] Thank you.', 'LISTENING', 'https://example.com/audio12.mp3', 'ACTIVE', '2025-05-01 13:41:26', '2025-05-01 13:41:26'),
(15, 'Library Visit', '[SPEAKER_A] Where can I find science books?\n[SPEAKER_B] Aisle 4 on the right.\n[SPEAKER_A] Thanks!', 'LISTENING', 'https://example.com/audio13.mp3', 'ACTIVE', '2025-05-01 13:41:26', '2025-05-01 13:41:26'),
(16, 'Email to Supervisor', 'Dear Supervisor,\n\nI hope this message finds you well. I would like to request a meeting next week to discuss my current project.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:41:26', '2025-05-01 13:41:26'),
(17, 'Job Application', 'To whom it may concern,\n\nI am writing to apply for the Sales Manager position at your company.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:41:26', '2025-05-01 13:41:26'),
(18, 'Travel Blog Entry', 'Last week, I visited Rome. The city was full of life and history. I especially loved the Colosseum and the local cuisine.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:41:26', '2025-05-01 13:41:26'),
(19, 'Workshop Invitation', 'We are pleased to invite you to the annual Marketing Strategies Workshop held on August 12th at our main office.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:41:26', '2025-05-01 13:41:26'),
(20, 'Company Memo', 'All staff are required to complete the online security training by the end of the month.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:41:26', '2025-05-01 13:41:26'),
(21, 'Product Description', 'Our new SmartWatch 2.0 features a sleek design, heart rate monitor, and extended battery life.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:41:26', '2025-05-01 13:41:26'),
(22, 'News Article', 'The local government announced a new park renovation project starting next spring.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:41:26', '2025-05-01 13:41:26'),
(23, 'Instruction Manual', 'To install the software, double-click the setup file and follow the on-screen instructions.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:41:26', '2025-05-01 13:41:26'),
(24, 'Hotel Review', 'The hotel was clean and well-located, but the service could have been better.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:41:26', '2025-05-01 13:41:26'),
(25, 'FAQ Entry', 'Q: How do I reset my password?\nA: Click on \"Forgot Password\" on the login page and follow the instructions.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:41:26', '2025-05-01 13:41:26'),
(26, 'Reminder Email', 'Just a friendly reminder that your dentist appointment is scheduled for Monday at 10 AM.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:41:26', '2025-05-01 13:41:26'),
(27, 'Short Story Intro', 'It was a dark and stormy night when Sarah heard a knock on the door...', 'READING', NULL, 'ACTIVE', '2025-05-01 13:41:26', '2025-05-01 13:41:26'),
(28, 'Morning Routine', '[SPEAKER_A] Good morning! Ready for work?\n[SPEAKER_B] Almost, just grabbing coffee.\n[SPEAKER_A] Don’t be late!', 'LISTENING', 'https://example.com/audio14.mp3', 'ACTIVE', '2025-05-01 13:46:31', '2025-05-01 13:46:31'),
(29, 'Classroom Discussion', '[SPEAKER_A] Did everyone finish the assignment?\n[SPEAKER_B] I still need to submit mine.\n[SPEAKER_A] Please do so by noon.', 'LISTENING', 'https://example.com/audio15.mp3', 'ACTIVE', '2025-05-01 13:46:31', '2025-05-01 13:46:31'),
(30, 'Bank Appointment', '[SPEAKER_A] I need to open a savings account.\n[SPEAKER_B] Sure, do you have ID with you?\n[SPEAKER_A] Yes, here it is.', 'LISTENING', 'https://example.com/audio16.mp3', 'ACTIVE', '2025-05-01 13:46:31', '2025-05-01 13:46:31'),
(31, 'Airport Check-in', '[SPEAKER_A] Passport and ticket, please.\n[SPEAKER_B] Here you go.\n[SPEAKER_A] Thank you. Enjoy your flight.', 'LISTENING', 'https://example.com/audio17.mp3', 'ACTIVE', '2025-05-01 13:46:31', '2025-05-01 13:46:31'),
(32, 'Medical Emergency', '[SPEAKER_A] He collapsed while jogging.\n[SPEAKER_B] Call an ambulance now!\n[SPEAKER_A] Already on it!', 'LISTENING', 'https://example.com/audio18.mp3', 'ACTIVE', '2025-05-01 13:46:31', '2025-05-01 13:46:31'),
(33, 'Technical Support Call', '[SPEAKER_A] My internet is down again.\n[SPEAKER_B] Let me run a line test.\n[SPEAKER_A] Thanks, I’ll wait.', 'LISTENING', 'https://example.com/audio19.mp3', 'ACTIVE', '2025-05-01 13:46:31', '2025-05-01 13:46:31'),
(34, 'Car Rental', '[SPEAKER_A] I need a car for three days.\n[SPEAKER_B] Do you prefer automatic or manual?\n[SPEAKER_A] Automatic, please.', 'LISTENING', 'https://example.com/audio20.mp3', 'ACTIVE', '2025-05-01 13:46:31', '2025-05-01 13:46:31'),
(35, 'Job Interview', '[SPEAKER_A] Where do you see yourself in five years?\n[SPEAKER_B] Leading a successful team.\n[SPEAKER_A] Great answer.', 'LISTENING', 'https://example.com/audio21.mp3', 'ACTIVE', '2025-05-01 13:46:31', '2025-05-01 13:46:31'),
(36, 'Parent-Teacher Conference', '[SPEAKER_A] How is Sam doing in class?\n[SPEAKER_B] He’s very bright but needs to focus more.\n[SPEAKER_A] We’ll work on that.', 'LISTENING', 'https://example.com/audio22.mp3', 'ACTIVE', '2025-05-01 13:46:31', '2025-05-01 13:46:31'),
(37, 'Lost & Found', '[SPEAKER_A] I lost my backpack on the train.\n[SPEAKER_B] Can you describe it?\n[SPEAKER_A] It’s blue with a laptop inside.', 'LISTENING', 'https://example.com/audio23.mp3', 'ACTIVE', '2025-05-01 13:46:31', '2025-05-01 13:46:31'),
(38, 'Event Planning', '[SPEAKER_A] Let’s finalize the guest list.\n[SPEAKER_B] Sure, I’ll email it to you.\n[SPEAKER_A] Thanks.', 'LISTENING', 'https://example.com/audio24.mp3', 'ACTIVE', '2025-05-01 13:46:31', '2025-05-01 13:46:31'),
(39, 'Library Card Application', '[SPEAKER_A] I’d like to get a library card.\n[SPEAKER_B] Please fill this form.\n[SPEAKER_A] Will do.', 'LISTENING', 'https://example.com/audio25.mp3', 'ACTIVE', '2025-05-01 13:46:31', '2025-05-01 13:46:31'),
(40, 'Grocery Shopping', '[SPEAKER_A] Don’t forget the eggs!\n[SPEAKER_B] Already in the cart.\n[SPEAKER_A] Great, let’s check out.', 'LISTENING', 'https://example.com/audio26.mp3', 'ACTIVE', '2025-05-01 13:46:31', '2025-05-01 13:46:31'),
(41, 'Museum Notice', 'The National Art Museum will be closed on Monday due to maintenance work. We apologize for the inconvenience.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:46:31', '2025-05-01 13:46:31'),
(42, 'Company Newsletter', 'This quarter, we launched two new products and expanded our customer service team. Thank you for your continued support.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:46:31', '2025-05-01 13:46:31'),
(43, 'Invitation Letter', 'You are cordially invited to the Graduation Ceremony on June 15th at the university auditorium.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:46:31', '2025-05-01 13:46:31'),
(44, 'Weather Report', 'Today’s forecast: partly cloudy with a high of 24°C and a chance of light showers in the afternoon.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:46:31', '2025-05-01 13:46:31'),
(45, 'Safety Instructions', 'In case of fire, use the stairs and avoid elevators. Follow emergency exit signs to evacuate the building safely.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:46:31', '2025-05-01 13:46:31'),
(46, 'Internship Announcement', 'We are offering summer internships for undergraduate students in the Marketing and IT departments. Apply before May 30th.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:46:31', '2025-05-01 13:46:31'),
(47, 'Recipe Introduction', 'This easy-to-make pasta recipe only requires five ingredients and is ready in under 30 minutes.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:46:31', '2025-05-01 13:46:31'),
(48, 'Parking Regulations', 'Parking is prohibited in fire lanes and loading zones. Unauthorized vehicles will be towed at the owner\'s expense.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:46:31', '2025-05-01 13:46:31'),
(49, 'Conference Schedule', 'The keynote speech will begin at 9:00 AM, followed by breakout sessions on business strategy and innovation.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:46:31', '2025-05-01 13:46:31'),
(50, 'Training Email', 'Reminder: Your first training session starts next Tuesday at 3:00 PM in Room 402. Bring a notebook and pen.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:46:31', '2025-05-01 13:46:31'),
(51, 'Environmental Tip', 'Reduce waste by bringing reusable bags when shopping. Small changes can have a big impact on the environment.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:46:31', '2025-05-01 13:46:31'),
(52, 'Lost Item Poster', 'Lost: Black leather wallet near Central Park on April 10th. If found, please call 555-0198. Reward offered.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:46:31', '2025-05-01 13:46:31'),
(53, 'Office Memo', 'Please remember to submit your weekly reports by Friday at 5 PM. Late submissions will not be accepted.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:48:42', '2025-05-01 13:48:42'),
(54, 'Travel Advisory', 'Travelers are advised to check local COVID-19 restrictions before booking flights to international destinations.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:48:42', '2025-05-01 13:48:42'),
(55, 'Exam Instructions', 'Do not open your booklet until instructed. Use only a pencil, and fill in the bubbles completely.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:48:42', '2025-05-01 13:48:42'),
(56, 'Library Rules', 'Eating and drinking are not allowed in the reading room. Mobile phones must be set to silent mode.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:48:42', '2025-05-01 13:48:42'),
(57, 'Job Posting', 'We are hiring a full-time graphic designer with at least 2 years of experience and a strong portfolio.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:48:42', '2025-05-01 13:48:42'),
(58, 'Event Invitation', 'Join us for the 10th Annual Charity Gala on Saturday, September 10 at the Downtown Conference Center.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:48:42', '2025-05-01 13:48:42'),
(59, 'Community Announcement', 'Street cleaning will take place on the first Monday of every month. Vehicles must be moved by 7 AM.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:48:42', '2025-05-01 13:48:42'),
(60, 'Health Tip', 'Drinking at least 8 cups of water a day helps maintain hydration and supports proper body function.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:48:42', '2025-05-01 13:48:42'),
(61, 'Holiday Hours', 'Our store will be open from 10 AM to 4 PM on Christmas Eve and closed on Christmas Day.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:48:42', '2025-05-01 13:48:42'),
(62, 'Product Description', 'This wireless headset offers noise cancellation and 20 hours of battery life for uninterrupted listening.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:48:42', '2025-05-01 13:48:42'),
(63, 'Study Tips', 'Divide your study material into small sections and review them regularly for better retention.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:48:42', '2025-05-01 13:48:42'),
(64, 'Customer Review', 'I was very pleased with the product quality and fast shipping. Would definitely order again!', 'READING', NULL, 'ACTIVE', '2025-05-01 13:48:42', '2025-05-01 13:48:42'),
(65, 'Tech Update', 'The latest smartphone features an upgraded camera system and a faster processor for improved performance.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:48:42', '2025-05-01 13:48:42'),
(66, 'Ordering Pizza', '[SPEAKER_A] Hello, I’d like to order a large pepperoni pizza.\n[SPEAKER_B] Would you like extra cheese?\n[SPEAKER_A] Yes, please.', 'LISTENING', 'https://example.com/audio27.mp3', 'ACTIVE', '2025-05-01 13:48:42', '2025-05-01 13:48:42'),
(67, 'Doctor Appointment', '[SPEAKER_A] What symptoms are you experiencing?\n[SPEAKER_B] I have a sore throat and mild fever.\n[SPEAKER_A] Let’s do a quick test.', 'LISTENING', 'https://example.com/audio28.mp3', 'ACTIVE', '2025-05-01 13:48:42', '2025-05-01 13:48:42'),
(68, 'Meeting Reschedule', '[SPEAKER_A] Can we move the meeting to Thursday?\n[SPEAKER_B] Sure, Thursday works better for me too.\n[SPEAKER_A] Great, I’ll update the calendar.', 'LISTENING', 'https://example.com/audio29.mp3', 'ACTIVE', '2025-05-01 13:48:42', '2025-05-01 13:48:42'),
(69, 'Tourist Info', '[SPEAKER_A] What time does the museum open?\n[SPEAKER_B] At 10 AM. It closes at 6 PM.\n[SPEAKER_A] Thank you.', 'LISTENING', 'https://example.com/audio30.mp3', 'ACTIVE', '2025-05-01 13:48:42', '2025-05-01 13:48:42'),
(70, 'Making Reservations', '[SPEAKER_A] I’d like a table for two at 7 PM.\n[SPEAKER_B] Do you prefer indoor or outdoor seating?\n[SPEAKER_A] Indoor, please.', 'LISTENING', 'https://example.com/audio31.mp3', 'ACTIVE', '2025-05-01 13:48:42', '2025-05-01 13:48:42'),
(71, 'Returning a Purchase', '[SPEAKER_A] I’d like to return this jacket.\n[SPEAKER_B] Do you have the receipt?\n[SPEAKER_A] Yes, here it is.', 'LISTENING', 'https://example.com/audio32.mp3', 'ACTIVE', '2025-05-01 13:48:42', '2025-05-01 13:48:42'),
(72, 'Asking Directions', '[SPEAKER_A] Excuse me, how do I get to the train station?\n[SPEAKER_B] Go straight two blocks and turn right.\n[SPEAKER_A] Thank you so much!', 'LISTENING', 'https://example.com/audio33.mp3', 'ACTIVE', '2025-05-01 13:48:42', '2025-05-01 13:48:42'),
(73, 'Team Meeting', '[SPEAKER_A] We need to finalize the budget.\n[SPEAKER_B] I’ll send the latest numbers by 3 PM.\n[SPEAKER_A] Perfect, thank you.', 'LISTENING', 'https://example.com/audio34.mp3', 'ACTIVE', '2025-05-01 13:48:42', '2025-05-01 13:48:42'),
(74, 'Hotel Check-In', '[SPEAKER_A] Welcome to Seaside Hotel. Do you have a reservation?\n[SPEAKER_B] Yes, under the name Miller.\n[SPEAKER_A] One moment, please.', 'LISTENING', 'https://example.com/audio35.mp3', 'ACTIVE', '2025-05-01 13:48:42', '2025-05-01 13:48:42'),
(75, 'Shopping for Shoes', '[SPEAKER_A] Do you have these in size 9?\n[SPEAKER_B] Let me check in the back.\n[SPEAKER_A] Thank you.', 'LISTENING', 'https://example.com/audio36.mp3', 'ACTIVE', '2025-05-01 13:48:42', '2025-05-01 13:48:42'),
(76, 'Dentist Visit', '[SPEAKER_A] Are you experiencing any pain?\n[SPEAKER_B] Yes, in the lower left molar.\n[SPEAKER_A] Let’s take a quick X-ray.', 'LISTENING', 'https://example.com/audio37.mp3', 'ACTIVE', '2025-05-01 13:48:42', '2025-05-01 13:48:42'),
(77, 'Laundry Pickup', '[SPEAKER_A] I’m here to pick up my clothes.\n[SPEAKER_B] Can I have your ticket?\n[SPEAKER_A] Sure, here it is.', 'LISTENING', 'https://example.com/audio38.mp3', 'ACTIVE', '2025-05-01 13:48:42', '2025-05-01 13:48:42'),
(78, 'Weather Report', 'Today will be sunny with a high of 28°C and low humidity. Perfect weather for outdoor activities.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:51:53', '2025-05-01 13:51:53'),
(79, 'Notice to Employees', 'All employees are required to wear ID badges at all times while in the office premises.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:51:53', '2025-05-01 13:51:53'),
(80, 'Online Purchase Receipt', 'Thank you for your purchase! Your order #3452 will be shipped within 3 business days.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:51:53', '2025-05-01 13:51:53'),
(81, 'Safety Reminder', 'Always wear a helmet when riding a bicycle. Your safety is our priority.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:51:53', '2025-05-01 13:51:53'),
(82, 'Newsletter Excerpt', 'In this month’s issue, we explore sustainable living tips and interview eco-friendly entrepreneurs.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:51:53', '2025-05-01 13:51:53'),
(83, 'Workshop Outline', 'This workshop will cover the basics of time management and personal productivity.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:51:53', '2025-05-01 13:51:53'),
(84, 'Policy Update', 'Our refund policy has been updated. Items returned after 30 days will not be accepted.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:51:53', '2025-05-01 13:51:53'),
(85, 'Company Profile', 'TechNova Inc. is a leader in AI-driven solutions for the healthcare and finance industries.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:51:53', '2025-05-01 13:51:53'),
(86, 'Public Service Announcement', 'Please conserve water. Limit outdoor watering to early mornings or late evenings.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:51:53', '2025-05-01 13:51:53'),
(87, 'Weekly Digest', 'Your personalized news feed summary includes top articles on technology, health, and education.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:51:53', '2025-05-01 13:51:53'),
(88, 'User Guide', 'To install the software, double-click the setup file and follow the on-screen instructions.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:51:53', '2025-05-01 13:51:53'),
(89, 'Fitness Program', 'This 6-week program includes cardio, strength training, and nutritional planning.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:51:53', '2025-05-01 13:51:53'),
(90, 'Product Recall', 'We are recalling product batch 2318 due to a packaging defect. Please return it for a refund.', 'READING', NULL, 'ACTIVE', '2025-05-01 13:51:53', '2025-05-01 13:51:53'),
(91, 'Banking Inquiry', '[SPEAKER_A] What’s the balance on my savings account?\n[SPEAKER_B] One moment, I’ll check for you.\n[SPEAKER_A] Thank you.', 'LISTENING', 'https://example.com/audio39.mp3', 'ACTIVE', '2025-05-01 13:51:53', '2025-05-01 13:51:53'),
(92, 'Restaurant Complaint', '[SPEAKER_A] My food is cold.\n[SPEAKER_B] I’m very sorry. Would you like me to reheat it?\n[SPEAKER_A] Yes, please.', 'LISTENING', 'https://example.com/audio40.mp3', 'ACTIVE', '2025-05-01 13:51:53', '2025-05-01 13:51:53'),
(93, 'Classroom Discussion', '[SPEAKER_A] What is the capital of Peru?\n[SPEAKER_B] Lima.\n[SPEAKER_A] Correct!', 'LISTENING', 'https://example.com/audio41.mp3', 'ACTIVE', '2025-05-01 13:51:53', '2025-05-01 13:51:53'),
(94, 'Movie Ticket Booking', '[SPEAKER_A] I’d like two tickets for the 6 PM show.\n[SPEAKER_B] Do you prefer front or middle row?\n[SPEAKER_A] Middle, please.', 'LISTENING', 'https://example.com/audio42.mp3', 'ACTIVE', '2025-05-01 13:51:53', '2025-05-01 13:51:53'),
(95, 'Bus Station Info', '[SPEAKER_A] When is the next bus to downtown?\n[SPEAKER_B] In 15 minutes.\n[SPEAKER_A] Thanks!', 'LISTENING', 'https://example.com/audio43.mp3', 'ACTIVE', '2025-05-01 13:51:53', '2025-05-01 13:51:53'),
(96, 'Apartment Inquiry', '[SPEAKER_A] Is the two-bedroom apartment still available?\n[SPEAKER_B] Yes, would you like to schedule a tour?\n[SPEAKER_A] That would be great.', 'LISTENING', 'https://example.com/audio44.mp3', 'ACTIVE', '2025-05-01 13:51:53', '2025-05-01 13:51:53'),
(97, 'Post Office Visit', '[SPEAKER_A] I need to send this package overnight.\n[SPEAKER_B] Please fill out this form.\n[SPEAKER_A] Done, thank you.', 'LISTENING', 'https://example.com/audio45.mp3', 'ACTIVE', '2025-05-01 13:51:53', '2025-05-01 13:51:53'),
(98, 'Hair Salon Call', '[SPEAKER_A] Can I book a haircut for tomorrow?\n[SPEAKER_B] We have an opening at 11 AM.\n[SPEAKER_A] I’ll take it.', 'LISTENING', 'https://example.com/audio46.mp3', 'ACTIVE', '2025-05-01 13:51:53', '2025-05-01 13:51:53'),
(99, 'Daily Routine', '[SPEAKER_A] I usually wake up at 6 AM.\n[SPEAKER_B] That’s early!\n[SPEAKER_A] I like to get a head start.', 'LISTENING', 'https://example.com/audio47.mp3', 'ACTIVE', '2025-05-01 13:51:53', '2025-05-01 13:51:53'),
(100, 'Grocery Store', '[SPEAKER_A] Where can I find the milk????\n[SPEAKER_B] Aisle 5, next to the cheese.\n[SPEAKER_A] Thanks!', 'LISTENING', 'https://example.com/audio48.mp3', 'ACTIVE', '2025-05-01 13:51:53', '2025-05-08 21:26:29'),
(101, 'Morning Exercise', '[SPEAKER_A] Are you ready for our run?\n[SPEAKER_B] Yes, let me grab my water.\n[SPEAKER_A] Don’t forget sunscreen!', 'LISTENING', 'https://example.com/audio49.mp3', 'ACTIVE', '2025-05-01 13:51:53', '2025-05-01 13:51:53'),
(102, 'School Pickup', '[SPEAKER_A] I’m here to pick up my son, Daniel.\n[SPEAKER_B] He’s in Room 204.\n[SPEAKER_A] Thank you.', 'LISTENING', 'https://example.com/audio50.mp3', 'ACTIVE', '2025-05-01 13:51:53', '2025-05-01 13:51:53'),
(103, 'Reading Passage – Business Memo', 'To: All Staff\nFrom: Human Resources Department\nDate: May 9, 2025\nSubject: New Remote Work Policy\n\nAs part of our continued efforts to improve employee satisfaction and productivity, we are pleased to announce a new remote work policy. Beginning June 1, employees will be allowed to work from home up to three days per week, depending on departmental needs and manager approval.\n\nTo support this transition, the company will provide a stipend of $150 to assist with home office setup. We encourage all employees to speak with their supervisors to determine a schedule that works best for their team.\n\nTraining on remote collaboration tools will be offered next week. Please check your email for registration details.\n\nWe believe this change will help promote a better work-life balance and contribute to a more flexible and efficient work environment.\n\nIf you have any questions, do not hesitate to contact HR.', 'READING', '', 'ACTIVE', '2025-05-08 21:21:36', '2025-05-08 21:33:03'),
(104, 'The Lost Phone', 'Last Saturday, Emma went to the park with her little brother to play soccer. It was a sunny day, and the park was full of people. After playing for an hour, they sat under a tree to rest. Emma took out her phone to check the time, but then she put it on the grass and forgot about it', 'LISTENING', 'https://storage.googleapis.com/necdiagnostics-bucket/audios/20250528-dcec30082ef5431c9acebfd5883e6edc.mp3', 'ACTIVE', '2025-05-28 20:57:57', '2025-05-28 20:57:57'),
(105, 'The Lost Phone 2', 'Last Saturday, Emma went to the park with her little brother to play soccer. It was a sunny day, and the park was full of people. NEW AUDIO.', 'LISTENING', 'https://storage.googleapis.com/necdiagnostics-bucket/audios/20250528-25b54aa08ad24004a952d90bf044469e.mp3', 'ACTIVE', '2025-05-28 21:18:11', '2025-05-28 21:31:17'),
(106, 'The Lost Phone 3', 'After playing for an hour, they sat under a tree to rest. Emma took out her phone to check the time, but then she put it on the grass and forgot about it.', 'READING', NULL, 'ACTIVE', '2025-05-28 21:19:32', '2025-05-28 21:19:32'),
(107, 'Short Talk', 'person 1: Hello, how are you?\nperson 2: Fine, thank you.', 'LISTENING', 'https://storage.googleapis.com/necdiagnostics-bucket/audios/20250607-77af993e21a342ee8655a80fd5509116.mp3', 'ACTIVE', '2025-06-07 13:19:01', '2025-06-07 13:19:01');

-- --------------------------------------------------------

--
-- Table structure for table `recommendations`
--

CREATE TABLE `recommendations` (
  `pk_recommend` int(11) NOT NULL,
  `test_fk` int(11) NOT NULL,
  `recommendation_text` text NOT NULL,
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `recommendations`
--

INSERT INTO `recommendations` (`pk_recommend`, `test_fk`, `recommendation_text`, `created_at`, `updated_at`) VALUES
(6, 29, 'To improve, the student should practice more with reading comprehension exercises focusing on detail-oriented questions to enhance their ability to catch specific information. For listening comprehension, engaging with a variety of audio materials, especially those involving interviews or conversations, can help in better understanding the context and nuances of spoken English. Additionally, taking timed practice tests can aid in improving both speed and accuracy in identifying correct answers.', '2025-05-05 15:20:16', '2025-05-05 15:20:16'),
(7, 29, 'To improve, the student should focus on enhancing their attention to detail, particularly with dates and specific information in reading passages. Practicing with timed reading exercises can help. For listening comprehension, engaging with a variety of English audio materials, especially those involving interviews or conversations, can aid in better understanding context and distinguishing between similar questions. Additionally, taking practice TOEIC tests will familiarize them with the exam format and improve their ability to manage time effectively during the test.', '2025-05-05 15:22:34', '2025-05-05 15:22:34'),
(8, 29, 'To improve, the student should practice more with reading comprehension exercises focusing on detail-oriented questions to enhance their ability to catch specific information. For listening comprehension, engaging with a variety of audio materials, especially those involving interviews or conversations, can help in better understanding the context and nuances of spoken English. Additionally, taking timed practice tests can aid in improving both speed and accuracy in identifying correct answers.', '2025-05-07 17:40:25', '2025-05-07 17:40:25'),
(9, 29, 'To improve, the student should practice more with reading comprehension exercises, focusing on extracting specific details from texts. For listening, engaging with a variety of English audio materials and practicing note-taking can help in better understanding and remembering details. Additionally, reviewing common question patterns in the TOEIC exam and taking timed practice tests will aid in improving both speed and accuracy.', '2025-05-07 17:43:45', '2025-05-07 17:43:45'),
(10, 29, 'To improve, the student should practice more with reading comprehension exercises focusing on detail-oriented questions to enhance their ability to catch specific information. For listening comprehension, engaging with a variety of audio materials, especially those involving interviews or conversations, can help in better understanding the context and nuances of spoken English. Additionally, taking timed practice tests can aid in improving both speed and accuracy in identifying correct answers.', '2025-05-09 11:06:35', '2025-05-09 11:06:35'),
(11, 29, 'To improve reading comprehension, the student should practice skimming and scanning techniques to better locate specific information in texts, such as dates and key details. For listening skills, engaging with a variety of English audio materials, especially those involving interviews or conversations, can help enhance the ability to discern main ideas and details. Additionally, focusing on question interpretation and practicing with TOEIC-specific listening exercises will be beneficial.', '2025-05-21 12:40:22', '2025-05-21 12:40:22'),
(12, 29, 'Begin with foundational English language learning to reach at least an A2 level before attempting TOEIC preparation. Focus on basic vocabulary, grammar, and comprehension skills.', '2025-05-21 12:56:05', '2025-05-21 12:56:05'),
(13, 29, 'Familiarize yourself with the TOEIC exam format and types of questions asked in both the READING and LISTENING sections. Practice with sample questions and exams to understand the expectations.', '2025-05-21 12:56:05', '2025-05-21 12:56:05'),
(14, 29, 'Engage in regular English language practice, including reading, writing, listening, and speaking, to improve overall proficiency. Use resources like language learning apps, online courses, and language exchange meetups.', '2025-05-21 12:56:05', '2025-05-21 12:56:05'),
(15, 29, 'To improve, the student should focus on enhancing their attention to detail by practicing with more reading and listening exercises that require identifying specific information. They should also expand their vocabulary, especially terms related to time and professional contexts. Additionally, practicing with TOEIC-style questions will help them become more familiar with the format and types of questions asked, improving their overall test-taking strategy.', '2025-05-21 12:58:42', '2025-05-21 12:58:42'),
(16, 29, 'To improve, the student should focus on enhancing their attention to detail, especially for dates and specific information in both reading and listening sections. Practicing with more listening exercises that involve understanding questions and responses in interviews or conversations would be beneficial. Additionally, engaging with a variety of reading materials that include deadlines and specific instructions could help in accurately identifying such details. Regular practice with TOEIC-specific materials that mimic the exam\'s format and question types is also recommended to familiarize themselves with the test\'s structure and improve overall performance.', '2025-05-21 12:59:57', '2025-05-21 12:59:57'),
(17, 29, 'To improve performance, the student should practice more with reading comprehension exercises focusing on extracting and remembering specific details. For listening skills, engaging with a variety of English audio materials, especially those simulating interview scenarios, can help in better understanding context and nuances. Additionally, taking notes during listening exercises may aid in retaining key information. Regular practice with TOEIC-style questions, particularly those at the B1 and B2 levels, will also be beneficial in addressing these weaknesses.', '2025-05-26 08:50:26', '2025-05-26 08:50:26'),
(18, 41, 'To improve reading comprehension, the student should practice with texts of varying difficulty levels, focusing on understanding main ideas and details. For listening skills, engaging with English audio materials, such as podcasts or news broadcasts, and practicing note-taking can enhance the ability to catch and remember key points. Additionally, working on vocabulary and grammar exercises tailored to the TOEIC format will help in addressing specific weaknesses identified in the test.', '2025-05-26 11:27:10', '2025-05-26 11:27:10'),
(19, 41, 'To improve, the student should focus on enhancing their comprehension skills at the A1 and A2 levels by practicing with simpler texts and listening exercises. Engaging with a variety of materials, such as news articles, simple stories, and instructional texts, can help. For listening, practicing with short conversations and focusing on key details will be beneficial. Additionally, the student should work on answering all questions, even if uncertain, to improve time management and guessing strategies. Regular practice with TOEIC-specific materials will also help familiarize the student with the exam format and question types.', '2025-05-26 11:27:32', '2025-05-26 11:27:32'),
(20, 29, 'To improve, the student should practice more with reading comprehension exercises focusing on dates and deadlines to enhance their attention to detail. For listening, engaging in exercises that simulate interview scenarios could help in better understanding questions and responses. Utilizing TOEIC practice tests that cover a wide range of topics and question types would also be beneficial in addressing these areas of weakness.', '2025-05-26 11:33:17', '2025-05-26 11:33:17'),
(21, 54, 'The student should focus on building a strong foundation in English vocabulary and grammar, starting with A1 level materials. Practicing with TOEIC-specific exercises can help familiarize them with the exam format. Additionally, working on reading and listening comprehension skills through daily practice with English texts and audio materials is essential. Time management strategies should also be developed to ensure all questions are attempted in future tests.', '2025-05-27 22:24:17', '2025-05-27 22:24:17'),
(22, 63, 'To improve, the student should focus on expanding their vocabulary and practicing with materials that cover a wide range of topics to enhance comprehension skills. Regular practice with TOEIC-style questions, especially those at the A2 and B1 levels, will help. For listening, engaging with English audio materials daily can improve comprehension and speed. For reading, practicing skimming and scanning techniques will aid in quickly identifying key information. Additionally, working on time management during the test is crucial to ensure all questions are attempted.', '2025-06-07 13:14:34', '2025-06-07 13:14:34'),
(23, 64, 'Focus on improving reading comprehension skills by practicing with a variety of texts, including notices, emails, and articles, to become familiar with different writing styles and vocabularies.', '2025-06-16 23:25:40', '2025-06-16 23:25:40'),
(24, 64, 'Work on grammar and vocabulary, especially verb tenses and prepositions, through targeted exercises and by reading extensively to see these elements used in context.', '2025-06-16 23:25:40', '2025-06-16 23:25:40'),
(25, 64, 'Develop strategies for managing time during the test to ensure all questions are attempted, such as skimming texts for key information before answering questions.', '2025-06-16 23:25:40', '2025-06-16 23:25:40'),
(26, 64, 'Enhance listening skills by engaging with English in diverse formats, such as podcasts, movies, and conversations, focusing on understanding main ideas and specific details.', '2025-06-16 23:25:40', '2025-06-16 23:25:40'),
(27, 64, 'Practice answering TOEIC-style questions under timed conditions to build confidence and improve accuracy in both reading and listening sections.', '2025-06-16 23:25:40', '2025-06-16 23:25:40'),
(28, 65, 'Focus on building basic vocabulary and grammar skills to improve comprehension of simple texts and conversations.', '2025-06-16 23:39:37', '2025-06-16 23:39:37'),
(29, 65, 'Practice reading short, simple texts and answering questions about them to improve reading comprehension skills.', '2025-06-16 23:39:37', '2025-06-16 23:39:37'),
(30, 65, 'Listen to basic English conversations and try to identify key information, such as names, places, and times, to improve listening comprehension.', '2025-06-16 23:39:37', '2025-06-16 23:39:37'),
(31, 65, 'Use flashcards or apps to learn common words and phrases that appear in the TOEIC exam.', '2025-06-16 23:39:37', '2025-06-16 23:39:37'),
(32, 65, 'Engage in daily English practice, including reading, writing, listening, and speaking, to gradually improve overall language proficiency.', '2025-06-16 23:39:37', '2025-06-16 23:39:37'),
(33, 67, 'Se recomienda enfocarse en construir un vocabulario básico y aprender estructuras gramaticales simples para mejorar la comprensión lectora y auditiva.', '2025-06-17 00:24:11', '2025-06-17 00:24:11'),
(34, 67, 'Practicar con materiales de inglés básico, como libros para principiantes y grabaciones de conversaciones simples, puede ayudar al estudiante a familiarizarse con el idioma.', '2025-06-17 00:24:11', '2025-06-17 00:24:11'),
(35, 67, 'El estudiante debería comenzar con ejercicios de escucha y lectura muy básicos, gradualmente aumentando la dificultad a medida que mejora su comprensión.', '2025-06-17 00:24:11', '2025-06-17 00:24:11'),
(36, 67, 'Tomar un curso de inglés básico o utilizar aplicaciones de aprendizaje de idiomas diseñadas para principiantes podría proporcionar una base sólida para el desarrollo futuro del idioma.', '2025-06-17 00:24:11', '2025-06-17 00:24:11'),
(37, 67, 'Se sugiere practicar la escritura y el habla en inglés en situaciones cotidianas simples para ganar confianza y mejorar la fluidez.', '2025-06-17 00:24:11', '2025-06-17 00:24:11'),
(38, 68, 'Iniciar con el estudio de vocabulario básico y estructuras gramaticales simples para construir una base sólida en inglés.', '2025-06-17 01:18:35', '2025-06-17 01:18:35'),
(39, 68, 'Practicar la comprensión lectora con textos muy sencillos, enfocándose en identificar información clave como fechas, lugares y acciones.', '2025-06-17 01:18:35', '2025-06-17 01:18:35'),
(40, 68, 'Escuchar conversaciones básicas en inglés, como las que se encuentran en materiales para principiantes, para mejorar la comprensión auditiva.', '2025-06-17 01:18:35', '2025-06-17 01:18:35'),
(41, 68, 'Realizar ejercicios específicos para el TOEIC que estén diseñados para niveles principiantes, con el fin de familiarizarse con el formato del examen.', '2025-06-17 01:18:35', '2025-06-17 01:18:35'),
(42, 68, 'Considerar la posibilidad de tomar clases de inglés básico o utilizar aplicaciones y recursos en línea diseñados para mejorar las habilidades lingüísticas desde el nivel A1.', '2025-06-17 01:18:35', '2025-06-17 01:18:35');

-- --------------------------------------------------------

--
-- Table structure for table `strengths`
--

CREATE TABLE `strengths` (
  `pk_strength` int(11) NOT NULL,
  `test_fk` int(11) NOT NULL,
  `strength_text` text NOT NULL,
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `strengths`
--

INSERT INTO `strengths` (`pk_strength`, `test_fk`, `strength_text`, `created_at`, `updated_at`) VALUES
(6, 29, 'The student demonstrates a good understanding of basic and intermediate level questions, particularly in reading comprehension where they correctly identified the type of internships offered and the departments involved. Their ability to grasp details from the listening section, such as the time frame and the candidate\'s aspirations, also indicates a solid foundation in listening comprehension.', '2025-05-05 15:20:16', '2025-05-05 15:20:16'),
(7, 29, 'The student demonstrates a good understanding of basic and intermediate level questions, particularly in identifying specific information in reading comprehension sections. For instance, they correctly answered questions about the type of internships offered and the departments involved, which are at A2 and B1 levels. In the listening section, they accurately identified the time frame mentioned and the candidate\'s aspirations, showing competence in understanding straightforward spoken English.', '2025-05-05 15:22:34', '2025-05-05 15:22:34'),
(8, 29, 'The student demonstrates a good understanding of basic and intermediate level questions, particularly in reading comprehension where they correctly identified the type of internships offered and the departments involved. Their ability to grasp details from the listening section, such as the time frame and the candidate\'s aspirations, also indicates a solid foundation in listening comprehension.', '2025-05-07 17:40:25', '2025-05-07 17:40:25'),
(9, 29, 'The student demonstrates a good understanding of B1 level questions, as seen in their correct answers regarding the type of internships offered and the candidate\'s aspirations in the listening section. They also correctly identified the time frame mentioned in the listening section and the departments offering internships in the reading section, showing proficiency in A2 level comprehension.', '2025-05-07 17:43:45', '2025-05-07 17:43:45'),
(10, 29, 'The student demonstrates a good understanding of basic and intermediate level questions, particularly in reading comprehension where they correctly identified the type of internships offered and the departments involved. Their ability to grasp details from the listening section, such as the time frame and the candidate\'s aspirations, also indicates a solid foundation in listening comprehension.', '2025-05-09 11:06:35', '2025-05-09 11:06:35'),
(11, 29, 'The student demonstrates a good understanding of basic to intermediate level reading comprehension questions, as evidenced by correctly answering questions about the type of internships offered and the departments involved. In the listening section, the student accurately identified the time frame mentioned and the candidate\'s aspirations, showing an ability to grasp key details from spoken English.', '2025-05-21 12:40:22', '2025-05-21 12:40:22'),
(12, 29, 'The student attempted to respond, showing a willingness to engage with the exam, which is a positive first step in language learning.', '2025-05-21 12:56:05', '2025-05-21 12:56:05'),
(13, 29, 'The student demonstrates a good understanding of basic and intermediate level questions, particularly in reading comprehension where they correctly answered questions about the type of internships offered and the departments involved. Their ability to grasp details from the listening section, such as the time frame mentioned and the candidate\'s aspirations, also indicates a solid foundation in listening comprehension.', '2025-05-21 12:58:42', '2025-05-21 12:58:42'),
(14, 29, 'The student demonstrates a good understanding of basic to intermediate level questions, particularly in the \'Reading comprehension\' section where they correctly answered questions about the type of internships being offered and the departments involved. Their ability to grasp and respond to \'Listening comprehension\' questions, especially those requiring understanding of specific details like time frames and aspirations, is also notable.', '2025-05-21 12:59:57', '2025-05-21 12:59:57'),
(15, 29, 'The student demonstrates a good understanding of basic and intermediate level questions, particularly in identifying specific information in the reading section, such as the type of internships offered and the departments involved. In the listening section, the student correctly identified the time frame mentioned and the candidate\'s aspirations, showing an ability to grasp key details from spoken English.', '2025-05-26 08:50:26', '2025-05-26 08:50:26'),
(16, 41, 'The student demonstrates a strong understanding of grammar and vocabulary at the B1 and B2 levels, as evidenced by correct answers in incomplete sentences and some reading comprehension questions. They are particularly good at identifying the correct word or phrase to complete a sentence, showing a solid grasp of English syntax and usage.', '2025-05-26 11:27:10', '2025-05-26 11:27:10'),
(17, 41, 'The student demonstrates a good understanding of grammar and vocabulary at the B1 and B2 levels, as evidenced by correct answers in \'Incomplete sentences\' and \'Reading comprehension\' sections. For example, correctly using \'for\' in \'She has been working here _______ five years.\' and understanding the context in \'All the orders got _________ on schedule.\' with \'delivered\'. The student also shows ability to comprehend and respond to questions about instructions and safety procedures, such as correctly identifying the main purpose of fire evacuation instructions.', '2025-05-26 11:27:32', '2025-05-26 11:27:32'),
(18, 29, 'The student demonstrates a good understanding of basic and intermediate level questions, particularly in identifying the type of internships offered and the departments involved. They also correctly answered questions related to the time frame mentioned in a conversation and the aspirations of a candidate, showing an ability to grasp key details in both reading and listening sections.', '2025-05-26 11:33:17', '2025-05-26 11:33:17'),
(19, 54, 'The student correctly identified the type of precipitation expected in one instance, showing a basic understanding of weather-related vocabulary.', '2025-05-27 22:24:17', '2025-05-27 22:24:17'),
(20, 63, 'The student demonstrated a basic understanding of simple texts and conversations, particularly in identifying the type of document in a reading comprehension question and correctly answering a question about who is calling in a listening comprehension section.', '2025-06-07 13:14:34', '2025-06-07 13:14:34'),
(21, 64, 'The student correctly answered questions related to basic conversations, such as ordering coffee, indicating a good understanding of simple, everyday English interactions.', '2025-06-16 23:25:40', '2025-06-16 23:25:40'),
(22, 64, 'In the section about the coffee order, the student accurately identified the size of the coffee, how the customer wanted their coffee, the likely location of the conversation, and what was offered by the barista, showing competence in listening comprehension for practical situations.', '2025-06-16 23:25:40', '2025-06-16 23:25:40'),
(23, 65, 'The student correctly identified the purpose of an environmental tip as \'To reduce waste\', demonstrating an understanding of the main idea in a simple text.', '2025-06-16 23:39:37', '2025-06-16 23:39:37'),
(24, 67, 'El estudiante no mostró fortalezas específicas en esta prueba, ya que la mayoría de las preguntas no fueron respondidas o fueron respondidas incorrectamente. Sin embargo, el intento de responder a algunas preguntas de comprensión lectora indica un nivel muy básico de compromiso con el material.', '2025-06-17 00:24:11', '2025-06-17 00:24:11');

-- --------------------------------------------------------

--
-- Table structure for table `study_materials`
--

CREATE TABLE `study_materials` (
  `pk_studymaterial` int(11) NOT NULL,
  `studymaterial_title` varchar(250) NOT NULL,
  `studymaterial_desc` text DEFAULT NULL,
  `studymaterial_type` varchar(20) DEFAULT NULL,
  `studymaterial_url` varchar(255) DEFAULT NULL,
  `level_fk` int(11) NOT NULL,
  `studymaterial_tags` varchar(200) DEFAULT NULL,
  `created_at` datetime DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `study_materials`
--

INSERT INTO `study_materials` (`pk_studymaterial`, `studymaterial_title`, `studymaterial_desc`, `studymaterial_type`, `studymaterial_url`, `level_fk`, `studymaterial_tags`, `created_at`) VALUES
(1, 'Material Test', 'test de material', 'PDF', 'https://storage.googleapis.com/necdiagnostics-bucket/f8ba9de0-0cbe-4647-b9f7-2f88d98dbc58-Bitacora_del_Proyecto_de_Tesis_NECDiagnostics.pdf', 2, 'PDF, BITACORA', '2025-05-28 21:56:25');

-- --------------------------------------------------------

--
-- Table structure for table `tests`
--

CREATE TABLE `tests` (
  `pk_test` int(11) NOT NULL,
  `user_fk` int(11) NOT NULL,
  `test_points` int(10) DEFAULT NULL,
  `test_passed` int(1) DEFAULT NULL,
  `status` varchar(25) NOT NULL DEFAULT 'IN_PROGRESS',
  `level_fk` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `tests`
--

INSERT INTO `tests` (`pk_test`, `user_fk`, `test_points`, `test_passed`, `status`, `level_fk`, `created_at`, `updated_at`) VALUES
(29, 2, 720, 1, 'COMPLETED', 3, '2025-05-01 16:44:00', '2025-05-26 11:33:17'),
(30, 3, NULL, NULL, 'IN_PROGRESS', NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(32, 3, NULL, NULL, 'IN_PROGRESS', NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(34, 2, NULL, NULL, 'IN_PROGRESS', NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(35, 1, NULL, NULL, 'IN_PROGRESS', NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(40, 1, NULL, NULL, 'IN_PROGRESS', NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(41, 13, 720, 1, 'COMPLETED', 3, '2025-05-26 11:22:25', '2025-05-26 11:27:32'),
(54, 1, 100, 0, 'COMPLETED', 1, '2025-05-27 22:22:42', '2025-05-27 22:24:17'),
(55, 1, NULL, NULL, 'IN_PROGRESS', NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(57, 1, NULL, NULL, 'IN_PROGRESS', NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(58, 1, NULL, NULL, 'IN_PROGRESS', NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(59, 1, NULL, NULL, 'IN_PROGRESS', NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(60, 1, NULL, NULL, 'IN_PROGRESS', NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(61, 1, NULL, NULL, 'IN_PROGRESS', NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(62, 1, NULL, NULL, 'IN_PROGRESS', NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(63, 1, 400, 0, 'COMPLETED', 2, '2025-06-07 13:12:18', '2025-06-07 13:14:34'),
(64, 16, 300, 0, 'COMPLETED', 2, '2025-06-16 23:24:45', '2025-06-16 23:25:40'),
(65, 18, 200, 0, 'COMPLETED', 1, '2025-06-16 23:38:48', '2025-06-16 23:39:37'),
(66, 18, NULL, NULL, 'IN_PROGRESS', NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(67, 18, 100, 0, 'COMPLETED', 1, '2025-06-17 00:23:29', '2025-06-17 00:24:11'),
(68, 18, 100, 0, 'COMPLETED', 1, '2025-06-17 01:18:07', '2025-06-17 01:18:35'),
(69, 1, NULL, NULL, 'IN_PROGRESS', NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(70, 1, NULL, NULL, 'IN_PROGRESS', NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(71, 1, NULL, NULL, 'IN_PROGRESS', NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44');

-- --------------------------------------------------------

--
-- Table structure for table `test_comments`
--

CREATE TABLE `test_comments` (
  `pk_comment` int(11) NOT NULL,
  `comment_title` varchar(100) DEFAULT NULL,
  `comment_value` text DEFAULT NULL,
  `user_fk` int(11) DEFAULT NULL,
  `test_fk` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `test_comments`
--

INSERT INTO `test_comments` (`pk_comment`, `comment_title`, `comment_value`, `user_fk`, `test_fk`, `created_at`, `updated_at`) VALUES
(1, 'Buen desempeño', 'El estudiante mostró una gran comprensión del tema.', 1, 29, '2025-05-13 13:41:10', '2025-05-13 13:41:10'),
(2, 'Buen desempeño', 'El estudiante mostró una gran comprensión del tema.', 1, 29, '2025-05-21 13:37:35', '2025-05-21 13:37:35'),
(3, 'Buen desempeño', 'El estudiante mostró una gran comprensión del tema.', 1, 29, '2025-05-21 13:38:17', '2025-05-21 13:38:17'),
(4, 'Nuevo título del comentario', 'Este es el nuevo contenido del comentario...', 1, 29, '2025-05-21 13:38:21', '2025-05-21 14:19:09'),
(5, 'Mejora en Vocabulario', 'En la pregunta 5, algo.', 1, 63, '2025-06-07 13:15:39', '2025-06-07 13:15:39'),
(6, 'dfdfdf', 'fdfdfsdffsdf', 1, 29, '2025-06-17 10:48:57', '2025-06-17 10:48:57'),
(7, 'Mejorar En Reading', 'Pon mas atencion', 1, 68, '2025-06-17 13:27:06', '2025-06-17 13:27:06'),
(8, 'Mejora en Vocabulario', 'Estudia vocabulario mas adecuado y tecnico aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 1, 68, '2025-06-17 13:35:52', '2025-06-17 13:35:52'),
(9, 'Lorem Ipsum', 'Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry\'s standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged.', 1, 68, '2025-06-17 13:36:37', '2025-06-17 13:36:55'),
(10, 'Prueba', 'sss', 1, 68, '2025-06-21 13:49:43', '2025-06-21 13:49:43');

-- --------------------------------------------------------

--
-- Table structure for table `test_details`
--

CREATE TABLE `test_details` (
  `pk_testdetail` int(11) NOT NULL,
  `test_fk` int(11) NOT NULL,
  `title_fk` int(11) NOT NULL,
  `question_fk` int(11) DEFAULT NULL,
  `answer_fk` int(11) DEFAULT NULL,
  `ai_comments` text DEFAULT NULL,
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `test_details`
--

INSERT INTO `test_details` (`pk_testdetail`, `test_fk`, `title_fk`, `question_fk`, `answer_fk`, `ai_comments`, `created_at`, `updated_at`) VALUES
(1, 29, 46, 119, 481, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"La respuesta correcta es \'May 30th\' según el contexto proporcionado.\"], \"sugerencias\": [\"Asegúrate de leer cuidadosamente el contexto para identificar la información relevante.\", \"Practica identificando fechas y plazos en textos similares para mejorar tu precisión.\"]}', '2025-05-01 16:44:00', '2025-06-17 10:48:03'),
(2, 29, 46, 121, 488, NULL, '2025-05-01 16:44:00', '2025-05-01 18:14:01'),
(3, 29, 46, 118, 488, NULL, '2025-05-01 16:44:00', '2025-05-01 18:14:01'),
(4, 29, 46, 120, 476, NULL, '2025-05-01 16:44:00', '2025-05-01 18:14:01'),
(5, 29, 35, 174, 701, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"El entrevistador pregunta sobre los planes del candidato en cinco años, no sobre su experiencia laboral previa.\"], \"sugerencias\": [\"Para responder correctamente, es importante escuchar atentamente la pregunta. En este caso, la pregunta se centra en las aspiraciones futuras del candidato, no en su historial laboral.\"]}', '2025-05-01 16:44:00', '2025-06-17 10:45:14'),
(6, 29, 35, 177, 712, NULL, '2025-05-01 16:44:00', '2025-05-01 18:14:01'),
(7, 29, 35, 176, 708, '{\"evaluacion\": \"correcta\", \"explicacion\": [\"La respuesta del candidato indica claramente su aspiración de liderar un equipo exitoso en el futuro.\"], \"sugerencias\": [\"Para enriquecer la respuesta, el candidato podría mencionar habilidades específicas que planea desarrollar para lograr este objetivo.\"]}', '2025-05-01 16:44:00', '2025-06-17 10:47:17'),
(8, 29, 35, 175, 704, '{\"evaluacion\": \"correcta\", \"explicacion\": [\"El entrevistador responde de manera positiva al decir \'Great answer\', lo que indica que está satisfecho con la respuesta del candidato.\"], \"sugerencias\": [\"Mantener respuestas claras y concisas como la del ejemplo puede ser efectivo en entrevistas.\"]}', '2025-05-01 16:44:00', '2025-06-17 10:45:42'),
(9, 30, 17, 68, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(10, 30, 17, 66, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(11, 30, 17, 67, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(12, 30, 17, 65, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(13, 30, 46, 118, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(14, 30, 46, 121, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(15, 30, 46, 119, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(16, 30, 46, 120, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(17, 30, 25, 98, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(18, 30, 25, 97, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(19, 30, 25, 100, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(20, 30, 25, 99, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(21, 30, 50, 134, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(22, 30, 50, 135, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(23, 30, 50, 137, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(24, 30, 50, 136, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(25, 30, 23, 89, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(26, 30, 23, 91, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(27, 30, 23, 90, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(28, 30, 23, 92, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(29, 30, 34, 170, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(30, 30, 34, 173, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(31, 30, 34, 171, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(32, 30, 34, 172, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(33, 30, 10, 39, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(34, 30, 10, 40, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(35, 30, 10, 38, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(36, 30, 10, 37, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(37, 30, 5, 17, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(38, 30, 5, 18, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(39, 30, 5, 19, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(40, 30, 5, 20, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(41, 30, 6, 22, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(42, 30, 6, 21, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(43, 30, 6, 24, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(44, 30, 6, 23, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(45, 30, 40, 197, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(46, 30, 40, 194, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(47, 30, 40, 195, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(48, 30, 40, 196, NULL, NULL, '2025-05-01 17:18:41', '2025-05-01 17:18:41'),
(57, 32, 25, 98, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(58, 32, 25, 100, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(59, 32, 25, 99, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(60, 32, 25, 97, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(61, 32, 1, 1, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(62, 32, 1, 3, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(63, 32, 1, 2, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(64, 32, 1, 4, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(65, 32, 20, 78, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(66, 32, 20, 79, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(67, 32, 20, 80, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(68, 32, 20, 77, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(69, 32, 47, 124, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(70, 32, 47, 125, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(71, 32, 47, 122, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(72, 32, 47, 123, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(73, 32, 45, 117, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(74, 32, 45, 114, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(75, 32, 45, 116, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(76, 32, 45, 115, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(77, 32, 24, 94, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(78, 32, 24, 95, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(79, 32, 24, 96, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(80, 32, 24, 93, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(81, 32, 18, 72, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(82, 32, 18, 70, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(83, 32, 18, 71, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(84, 32, 18, 69, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(85, 32, 16, 61, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(86, 32, 16, 62, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(87, 32, 16, 64, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(88, 32, 16, 63, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(89, 32, 23, 91, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(90, 32, 23, 92, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(91, 32, 23, 89, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(92, 32, 23, 90, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(93, 32, 21, 82, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(94, 32, 21, 84, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(95, 32, 21, 81, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(96, 32, 21, 83, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(97, 32, 9, 36, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(98, 32, 9, 33, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(99, 32, 9, 34, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(100, 32, 9, 35, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(101, 32, 39, 192, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(102, 32, 39, 191, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(103, 32, 39, 193, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(104, 32, 39, 190, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(105, 32, 5, 17, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(106, 32, 5, 18, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(107, 32, 5, 20, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(108, 32, 5, 19, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(109, 32, 35, 174, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(110, 32, 35, 176, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(111, 32, 35, 177, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(112, 32, 35, 175, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(113, 32, 36, 178, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(114, 32, 36, 180, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(115, 32, 36, 179, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(116, 32, 36, 181, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(117, 32, 13, 51, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(118, 32, 13, 49, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(119, 32, 13, 52, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(120, 32, 13, 50, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(121, 32, 3, 12, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(122, 32, 3, 9, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(123, 32, 3, 10, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(124, 32, 3, 11, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(125, 32, 12, 46, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(126, 32, 12, 45, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(127, 32, 12, 47, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(128, 32, 12, 48, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(129, 32, 32, 162, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(130, 32, 32, 165, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(131, 32, 32, 164, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(132, 32, 32, 163, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(133, 32, 38, 189, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(134, 32, 38, 187, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(135, 32, 38, 186, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(136, 32, 38, 188, NULL, NULL, '2025-05-01 17:21:05', '2025-05-01 17:21:05'),
(137, 34, 26, 104, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(138, 34, 26, 103, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(139, 34, 26, 101, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(140, 34, 26, 102, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(141, 34, 18, 69, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(142, 34, 18, 70, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(143, 34, 18, 72, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(144, 34, 18, 71, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(145, 34, 2, 7, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(146, 34, 2, 5, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(147, 34, 2, 8, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(148, 34, 2, 6, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(149, 34, 50, 135, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(150, 34, 50, 137, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(151, 34, 50, 136, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(152, 34, 50, 134, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(153, 34, 22, 88, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(154, 34, 22, 85, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(155, 34, 22, 87, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(156, 34, 22, 86, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(157, 34, 49, 130, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(158, 34, 49, 132, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(159, 34, 49, 133, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(160, 34, 49, 131, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(161, 34, 51, 138, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(162, 34, 51, 140, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(163, 34, 51, 141, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(164, 34, 51, 139, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(165, 34, 19, 73, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(166, 34, 19, 76, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(167, 34, 19, 74, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(168, 34, 19, 75, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(169, 34, 48, 127, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(170, 34, 48, 129, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(171, 34, 48, 128, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(172, 34, 48, 126, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(173, 34, 46, 120, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(174, 34, 46, 119, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(175, 34, 46, 121, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(176, 34, 46, 118, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(177, 34, 52, 143, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(178, 34, 52, 142, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(179, 34, 52, 145, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(180, 34, 52, 144, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(181, 34, 20, 77, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(182, 34, 20, 80, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(183, 34, 20, 79, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(184, 34, 20, 78, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(185, 34, 7, 26, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(186, 34, 7, 28, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(187, 34, 7, 27, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(188, 34, 7, 25, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(189, 34, 32, 165, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(190, 34, 32, 162, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(191, 34, 32, 163, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(192, 34, 32, 164, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(193, 34, 14, 54, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(194, 34, 14, 55, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(195, 34, 14, 53, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(196, 34, 14, 56, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(197, 34, 12, 46, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(198, 34, 12, 45, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(199, 34, 12, 47, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(200, 34, 12, 48, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(201, 34, 31, 160, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(202, 34, 31, 158, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(203, 34, 31, 159, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(204, 34, 31, 161, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(205, 34, 10, 39, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(206, 34, 10, 38, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(207, 34, 10, 37, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(208, 34, 10, 40, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(209, 34, 39, 192, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(210, 34, 39, 191, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(211, 34, 39, 193, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(212, 34, 39, 190, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(213, 34, 15, 58, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(214, 34, 15, 59, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(215, 34, 15, 60, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(216, 34, 15, 57, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(217, 34, 5, 17, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(218, 34, 5, 18, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(219, 34, 5, 19, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(220, 34, 5, 20, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(221, 34, 35, 175, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(222, 34, 35, 176, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(223, 34, 35, 177, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(224, 34, 35, 174, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(225, 34, 28, 148, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(226, 34, 28, 146, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(227, 34, 28, 149, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(228, 34, 28, 147, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(229, 34, 40, 194, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(230, 34, 40, 196, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(231, 34, 40, 195, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(232, 34, 40, 197, NULL, NULL, '2025-05-01 17:21:55', '2025-05-01 17:21:55'),
(233, 35, 1, 1, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(234, 35, 1, 4, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(235, 35, 1, 2, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(236, 35, 1, 3, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(237, 35, 17, 67, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(238, 35, 17, 65, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(239, 35, 17, 66, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(240, 35, 17, 68, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(241, 35, 2, 7, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(242, 35, 2, 5, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(243, 35, 2, 6, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(244, 35, 2, 8, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(245, 35, 52, 142, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(246, 35, 52, 145, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(247, 35, 52, 143, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(248, 35, 52, 144, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(249, 35, 25, 99, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(250, 35, 25, 98, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(251, 35, 25, 100, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(252, 35, 25, 97, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(253, 35, 23, 91, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(254, 35, 23, 92, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(255, 35, 23, 89, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(256, 35, 23, 90, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(257, 35, 22, 86, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(258, 35, 22, 85, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(259, 35, 22, 88, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(260, 35, 22, 87, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(261, 35, 47, 124, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(262, 35, 47, 125, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(263, 35, 47, 122, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(264, 35, 47, 123, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(265, 35, 21, 81, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(266, 35, 21, 82, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(267, 35, 21, 83, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(268, 35, 21, 84, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(269, 35, 24, 93, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(270, 35, 24, 96, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(271, 35, 24, 95, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(272, 35, 24, 94, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(273, 35, 44, 110, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(274, 35, 44, 113, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(275, 35, 44, 112, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(276, 35, 44, 111, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(277, 35, 16, 62, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(278, 35, 16, 63, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(279, 35, 16, 61, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(280, 35, 16, 64, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(281, 35, 13, 52, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(282, 35, 13, 49, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(283, 35, 13, 50, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(284, 35, 13, 51, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(285, 35, 36, 178, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(286, 35, 36, 180, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(287, 35, 36, 181, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(288, 35, 36, 179, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(289, 35, 4, 16, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(290, 35, 4, 14, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(291, 35, 4, 13, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(292, 35, 4, 15, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(293, 35, 33, 166, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(294, 35, 33, 167, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(295, 35, 33, 169, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(296, 35, 33, 168, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(297, 35, 10, 39, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(298, 35, 10, 38, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(299, 35, 10, 37, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(300, 35, 10, 40, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(301, 35, 40, 195, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(302, 35, 40, 194, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(303, 35, 40, 196, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(304, 35, 40, 197, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(305, 35, 14, 55, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(306, 35, 14, 53, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(307, 35, 14, 56, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(308, 35, 14, 54, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(309, 35, 39, 190, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(310, 35, 39, 192, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(311, 35, 39, 191, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(312, 35, 39, 193, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(313, 35, 37, 185, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(314, 35, 37, 184, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(315, 35, 37, 183, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(316, 35, 37, 182, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(317, 35, 32, 165, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(318, 35, 32, 163, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(319, 35, 32, 164, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(320, 35, 32, 162, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(321, 35, 28, 147, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(322, 35, 28, 148, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(323, 35, 28, 149, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(324, 35, 28, 146, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(325, 35, 6, 21, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(326, 35, 6, 23, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(327, 35, 6, 22, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(328, 35, 6, 24, NULL, NULL, '2025-05-01 17:22:14', '2025-05-01 17:22:14'),
(581, 40, 22, 88, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(582, 40, 22, 85, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(583, 40, 22, 87, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(584, 40, 22, 86, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(585, 40, 26, 101, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(586, 40, 26, 102, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(587, 40, 26, 103, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(588, 40, 26, 104, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(589, 40, 25, 98, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(590, 40, 25, 99, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(591, 40, 25, 100, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(592, 40, 25, 97, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(593, 40, 24, 96, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(594, 40, 24, 94, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(595, 40, 24, 93, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(596, 40, 24, 95, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(597, 40, 47, 124, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(598, 40, 47, 125, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(599, 40, 47, 123, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(600, 40, 47, 122, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(601, 40, 20, 77, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(602, 40, 20, 78, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(603, 40, 20, 79, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(604, 40, 20, 80, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(605, 40, 16, 62, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(606, 40, 16, 61, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(607, 40, 16, 63, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(608, 40, 16, 64, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(609, 40, 17, 65, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(610, 40, 17, 67, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(611, 40, 17, 66, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(612, 40, 17, 68, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(613, 40, 19, 75, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(614, 40, 19, 74, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(615, 40, 19, 73, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(616, 40, 19, 76, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(617, 40, 44, 110, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(618, 40, 44, 112, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(619, 40, 44, 111, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(620, 40, 44, 113, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(621, 40, 49, 130, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(622, 40, 49, 132, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(623, 40, 49, 133, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(624, 40, 49, 131, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(625, 40, 51, 139, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(626, 40, 51, 140, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(627, 40, 51, 141, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(628, 40, 51, 138, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(629, 40, 6, 23, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(630, 40, 6, 22, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(631, 40, 6, 21, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(632, 40, 6, 24, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(633, 40, 31, 159, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(634, 40, 31, 161, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(635, 40, 31, 160, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(636, 40, 31, 158, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(637, 40, 34, 172, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(638, 40, 34, 173, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(639, 40, 34, 170, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(640, 40, 34, 171, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(641, 40, 15, 60, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(642, 40, 15, 58, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(643, 40, 15, 57, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(644, 40, 15, 59, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(645, 40, 13, 50, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(646, 40, 13, 51, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(647, 40, 13, 52, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(648, 40, 13, 49, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(649, 40, 35, 174, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(650, 40, 35, 176, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(651, 40, 35, 175, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(652, 40, 35, 177, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(653, 40, 37, 182, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(654, 40, 37, 183, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(655, 40, 37, 185, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(656, 40, 37, 184, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(657, 40, 38, 189, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(658, 40, 38, 188, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(659, 40, 38, 186, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(660, 40, 38, 187, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(661, 40, 11, 44, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(662, 40, 11, 42, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(663, 40, 11, 41, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(664, 40, 11, 43, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(665, 40, 8, 31, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(666, 40, 8, 32, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(667, 40, 8, 29, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(668, 40, 8, 30, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(669, 40, 32, 164, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(670, 40, 32, 165, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(671, 40, 32, 162, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(672, 40, 32, 163, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(673, 40, 14, 56, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(674, 40, 14, 54, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(675, 40, 14, 55, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(676, 40, 14, 53, NULL, NULL, '2025-05-26 11:19:46', '2025-05-26 11:19:46'),
(677, 41, 51, 140, 566, NULL, '2025-05-26 11:22:25', '2025-05-26 11:27:10'),
(678, 41, 51, 141, 569, NULL, '2025-05-26 11:22:25', '2025-05-26 11:27:10'),
(679, 41, 51, 138, 557, NULL, '2025-05-26 11:22:25', '2025-05-26 11:27:10'),
(680, 41, 51, 139, 561, NULL, '2025-05-26 11:22:25', '2025-05-26 11:27:10'),
(681, 41, 26, 104, 435, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(682, 41, 26, 103, 431, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(683, 41, 26, 102, 427, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(684, 41, 26, 101, 424, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(685, 41, 2, 7, 26, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(686, 41, 2, 5, 20, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(687, 41, 2, 6, 24, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(688, 41, 2, 8, 29, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(689, 41, 27, 106, NULL, NULL, '2025-05-26 11:22:25', '2025-05-26 11:22:25'),
(690, 41, 27, 105, 438, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(691, 41, 27, 108, NULL, NULL, '2025-05-26 11:22:25', '2025-05-26 11:22:25'),
(692, 41, 27, 107, NULL, NULL, '2025-05-26 11:22:25', '2025-05-26 11:22:25'),
(693, 41, 24, 93, 391, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(694, 41, 24, 94, 395, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(695, 41, 24, 95, 399, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(696, 41, 24, 96, 402, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(697, 41, 48, 127, 513, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(698, 41, 48, 126, 510, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(699, 41, 48, 128, 518, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(700, 41, 48, 129, 521, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(701, 41, 23, 92, 387, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(702, 41, 23, 91, 384, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(703, 41, 23, 90, 378, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(704, 41, 23, 89, 375, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(705, 41, 49, 132, 533, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(706, 41, 49, 130, 527, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(707, 41, 49, 131, 529, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(708, 41, 49, 133, 537, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(709, 41, 47, 122, 494, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(710, 41, 47, 125, 505, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(711, 41, 47, 124, 501, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(712, 41, 47, 123, 497, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(713, 41, 25, 98, 410, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(714, 41, 25, 97, 406, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(715, 41, 25, 99, 415, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(716, 41, 25, 100, 418, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(717, 41, 45, 114, 461, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(718, 41, 45, 117, 472, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(719, 41, 45, 116, 468, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(720, 41, 45, 115, 465, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(721, 41, 22, 85, NULL, NULL, '2025-05-26 11:22:25', '2025-05-26 11:22:25'),
(722, 41, 22, 86, 353, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(723, 41, 22, 87, 356, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(724, 41, 22, 88, 361, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(725, 41, 39, 190, 764, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(726, 41, 39, 193, 777, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(727, 41, 39, 191, 769, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(728, 41, 39, 192, 773, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(729, 41, 37, 182, 734, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(730, 41, 37, 185, 745, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(731, 41, 37, 184, 741, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(732, 41, 37, 183, 739, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(733, 41, 15, 58, 241, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(734, 41, 15, 57, 236, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(735, 41, 15, 60, 247, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(736, 41, 15, 59, 244, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(737, 41, 28, 147, 593, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(738, 41, 28, 146, 588, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(739, 41, 28, 148, 598, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(740, 41, 28, 149, 601, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(741, 41, 12, 47, 196, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(742, 41, 12, 45, 186, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(743, 41, 12, 46, 191, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(744, 41, 12, 48, 199, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(745, 41, 31, 158, 636, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(746, 41, 31, 160, 644, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(747, 41, 31, 161, 649, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(748, 41, 31, 159, 640, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(749, 41, 32, 164, 661, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(750, 41, 32, 162, 653, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(751, 41, 32, 163, 656, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(752, 41, 32, 165, 664, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(753, 41, 30, 156, 628, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(754, 41, 30, 157, 633, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(755, 41, 30, 154, 621, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(756, 41, 30, 155, 624, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(757, 41, 36, 178, 716, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(758, 41, 36, 181, 730, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(759, 41, 36, 180, 724, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(760, 41, 36, 179, 720, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(761, 41, 6, 24, 102, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(762, 41, 6, 21, 90, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(763, 41, 6, 22, 94, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(764, 41, 6, 23, 100, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(765, 41, 34, 173, 697, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(766, 41, 34, 172, 694, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(767, 41, 34, 170, 686, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(768, 41, 34, 171, 689, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(769, 41, 29, 151, 610, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(770, 41, 29, 152, 614, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(771, 41, 29, 150, 604, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(772, 41, 29, 153, 617, NULL, '2025-05-26 11:22:25', '2025-05-26 11:26:53'),
(1233, 54, 18, 72, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1234, 54, 18, 70, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1235, 54, 18, 69, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1236, 54, 18, 71, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1237, 54, 44, 113, 456, '{\"evaluacion\": \"correcta\", \"explicacion\": [\"La respuesta proporcionada coincide con la información dada en el contexto, que menciona \'a chance of light showers in the afternoon\'.\"], \"sugerencias\": [\"Asegúrate de leer cuidadosamente el contexto para identificar detalles específicos como el tipo de precipitación.\"]}', '2025-05-27 22:22:42', '2025-06-16 23:24:13'),
(1238, 54, 44, 111, 451, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"La respuesta proporcionada fue \'15°C\', pero la temperatura máxima esperada según el contexto es \'24°C\'.\"], \"sugerencias\": [\"Asegúrate de leer cuidadosamente el contexto para identificar la información correcta. En este caso, la temperatura máxima esperada es claramente mencionada como 24°C.\"]}', '2025-05-27 22:22:42', '2025-06-16 23:23:51'),
(1239, 54, 44, 110, 445, NULL, '2025-05-27 22:22:42', '2025-05-27 22:24:03'),
(1240, 54, 44, 112, 454, NULL, '2025-05-27 22:22:42', '2025-05-27 22:24:03'),
(1241, 54, 22, 87, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1242, 54, 22, 88, 358, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"El texto proporcionado es una declaración o anuncio hecho por el gobierno local sobre un proyecto de renovación de un parque. No es un artículo de noticias ni instrucciones en pantalla, sino más bien un anuncio oficial o comunicado de prensa.\"], \"sugerencias\": [\"Para mejorar la comprensión, considera el contexto en el que se presenta la información. Los anuncios oficiales suelen ser directos y proporcionan información sobre acciones futuras o planes, como en este caso.\"]}', '2025-05-27 22:22:42', '2025-06-16 23:23:24'),
(1243, 54, 22, 86, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1244, 54, 22, 85, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1245, 54, 45, 115, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1246, 54, 45, 116, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1247, 54, 45, 117, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1248, 54, 45, 114, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1249, 54, 21, 82, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1250, 54, 21, 81, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1251, 54, 21, 83, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1252, 54, 21, 84, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1253, 54, 17, 67, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1254, 54, 17, 65, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1255, 54, 17, 68, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1256, 54, 17, 66, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1257, 54, 23, 89, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1258, 54, 23, 91, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1259, 54, 23, 92, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1260, 54, 23, 90, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1261, 54, 20, 77, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1262, 54, 20, 78, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1263, 54, 20, 79, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1264, 54, 20, 80, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1265, 54, 49, 130, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1266, 54, 49, 133, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1267, 54, 49, 131, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1268, 54, 49, 132, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1269, 54, 25, 98, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1270, 54, 25, 99, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1271, 54, 25, 97, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1272, 54, 25, 100, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1273, 54, 27, 107, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1274, 54, 27, 105, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1275, 54, 27, 106, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1276, 54, 27, 108, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1277, 54, 2, 8, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1278, 54, 2, 5, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1279, 54, 2, 6, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1280, 54, 2, 7, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1281, 54, 30, 154, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1282, 54, 30, 155, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1283, 54, 30, 156, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1284, 54, 30, 157, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1285, 54, 3, 12, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1286, 54, 3, 11, 52, NULL, '2025-05-27 22:22:42', '2025-05-27 22:24:02'),
(1287, 54, 3, 10, 48, NULL, '2025-05-27 22:22:42', '2025-05-27 22:24:02'),
(1288, 54, 3, 9, 42, '{\"evaluacion\": \"correcta\", \"explicacion\": [\"El cliente pide un café grande, como se menciona en la frase \'Hi, can I get a large coffee?\'\"], \"sugerencias\": [\"Asegúrate de prestar atención a los detalles específicos mencionados en la conversación para responder con precisión.\"]}', '2025-05-27 22:22:42', '2025-06-16 23:22:57'),
(1289, 54, 33, 166, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1290, 54, 33, 169, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1291, 54, 33, 168, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1292, 54, 33, 167, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1293, 54, 9, 35, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1294, 54, 9, 36, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1295, 54, 9, 34, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1296, 54, 9, 33, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1297, 54, 7, 26, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1298, 54, 7, 27, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1299, 54, 7, 28, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1300, 54, 7, 25, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1301, 54, 32, 164, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1302, 54, 32, 163, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1303, 54, 32, 162, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1304, 54, 32, 165, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1305, 54, 36, 179, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1306, 54, 36, 181, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1307, 54, 36, 178, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1308, 54, 36, 180, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1309, 54, 13, 50, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1310, 54, 13, 52, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1311, 54, 13, 51, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1312, 54, 13, 49, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1313, 54, 6, 22, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1314, 54, 6, 24, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1315, 54, 6, 21, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1316, 54, 6, 23, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1317, 54, 5, 19, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1318, 54, 5, 20, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1319, 54, 5, 17, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1320, 54, 5, 18, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1321, 54, 15, 58, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1322, 54, 15, 59, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1323, 54, 15, 60, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1324, 54, 15, 57, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1325, 54, 28, 148, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1326, 54, 28, 146, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1327, 54, 28, 147, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1328, 54, 28, 149, NULL, NULL, '2025-05-27 22:22:42', '2025-05-27 22:22:42'),
(1329, 55, 50, 137, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1330, 55, 50, 134, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1331, 55, 50, 136, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1332, 55, 50, 135, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1333, 55, 17, 65, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1334, 55, 17, 68, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1335, 55, 17, 66, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1336, 55, 17, 67, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1337, 55, 46, 119, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1338, 55, 46, 121, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1339, 55, 46, 118, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1340, 55, 46, 120, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1341, 55, 26, 103, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1342, 55, 26, 101, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1343, 55, 26, 102, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1344, 55, 26, 104, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1345, 55, 16, 64, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13');
INSERT INTO `test_details` (`pk_testdetail`, `test_fk`, `title_fk`, `question_fk`, `answer_fk`, `ai_comments`, `created_at`, `updated_at`) VALUES
(1346, 55, 16, 62, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1347, 55, 16, 63, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1348, 55, 16, 61, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1349, 55, 52, 142, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1350, 55, 52, 144, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1351, 55, 52, 145, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1352, 55, 52, 143, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1353, 55, 19, 76, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1354, 55, 19, 74, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1355, 55, 19, 73, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1356, 55, 19, 75, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1357, 55, 20, 77, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1358, 55, 20, 80, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1359, 55, 20, 79, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1360, 55, 20, 78, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1361, 55, 47, 125, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1362, 55, 47, 123, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1363, 55, 47, 122, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1364, 55, 47, 124, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1365, 55, 23, 91, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1366, 55, 23, 92, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1367, 55, 23, 90, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1368, 55, 23, 89, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1369, 55, 25, 97, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1370, 55, 25, 99, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1371, 55, 25, 100, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1372, 55, 25, 98, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1373, 55, 21, 83, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1374, 55, 21, 82, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1375, 55, 21, 84, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1376, 55, 21, 81, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1377, 55, 34, 172, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1378, 55, 34, 171, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1379, 55, 34, 170, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1380, 55, 34, 173, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1381, 55, 12, 47, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1382, 55, 12, 45, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1383, 55, 12, 48, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1384, 55, 12, 46, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1385, 55, 9, 33, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1386, 55, 9, 34, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1387, 55, 9, 35, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1388, 55, 9, 36, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1389, 55, 37, 183, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1390, 55, 37, 184, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1391, 55, 37, 182, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1392, 55, 37, 185, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1393, 55, 5, 17, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1394, 55, 5, 18, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1395, 55, 5, 20, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1396, 55, 5, 19, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1397, 55, 29, 153, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1398, 55, 29, 152, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1399, 55, 29, 151, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1400, 55, 29, 150, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1401, 55, 6, 22, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1402, 55, 6, 24, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1403, 55, 6, 23, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1404, 55, 6, 21, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1405, 55, 36, 181, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1406, 55, 36, 180, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1407, 55, 36, 179, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1408, 55, 36, 178, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1409, 55, 15, 58, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1410, 55, 15, 57, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1411, 55, 15, 60, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1412, 55, 15, 59, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1413, 55, 11, 44, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1414, 55, 11, 42, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1415, 55, 11, 43, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1416, 55, 11, 41, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1417, 55, 39, 190, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1418, 55, 39, 191, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1419, 55, 39, 192, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1420, 55, 39, 193, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1421, 55, 30, 156, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1422, 55, 30, 155, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1423, 55, 30, 154, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1424, 55, 30, 157, NULL, NULL, '2025-05-27 22:27:13', '2025-05-27 22:27:13'),
(1441, 57, 46, 120, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1442, 57, 46, 118, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1443, 57, 46, 121, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1444, 57, 46, 119, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1445, 57, 22, 87, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1446, 57, 22, 85, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1447, 57, 22, 86, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1448, 57, 22, 88, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1449, 57, 25, 98, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1450, 57, 25, 100, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1451, 57, 25, 99, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1452, 57, 25, 97, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1453, 57, 51, 138, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1454, 57, 51, 141, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1455, 57, 51, 139, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1456, 57, 51, 140, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1457, 57, 18, 71, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1458, 57, 18, 69, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1459, 57, 18, 70, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1460, 57, 18, 72, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1461, 57, 21, 81, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1462, 57, 21, 83, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1463, 57, 21, 82, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1464, 57, 21, 84, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1465, 57, 27, 108, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1466, 57, 27, 106, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1467, 57, 27, 107, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1468, 57, 27, 105, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1469, 57, 26, 103, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1470, 57, 26, 101, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1471, 57, 26, 102, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1472, 57, 26, 104, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1473, 57, 24, 93, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1474, 57, 24, 96, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1475, 57, 24, 95, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1476, 57, 24, 94, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1477, 57, 19, 75, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1478, 57, 19, 74, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1479, 57, 19, 73, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1480, 57, 19, 76, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1481, 57, 20, 77, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1482, 57, 20, 78, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1483, 57, 20, 80, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1484, 57, 20, 79, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1485, 57, 45, 117, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1486, 57, 45, 115, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1487, 57, 45, 116, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1488, 57, 45, 114, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1489, 57, 5, 20, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1490, 57, 5, 19, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1491, 57, 5, 17, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1492, 57, 5, 18, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1493, 57, 10, 37, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1494, 57, 10, 39, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1495, 57, 10, 38, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1496, 57, 10, 40, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1497, 57, 36, 178, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1498, 57, 36, 180, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1499, 57, 36, 181, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1500, 57, 36, 179, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1501, 57, 8, 30, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1502, 57, 8, 32, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1503, 57, 8, 29, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1504, 57, 8, 31, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1505, 57, 37, 182, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1506, 57, 37, 185, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1507, 57, 37, 184, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1508, 57, 37, 183, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1509, 57, 30, 157, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1510, 57, 30, 154, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1511, 57, 30, 156, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1512, 57, 30, 155, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1513, 57, 7, 26, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1514, 57, 7, 28, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1515, 57, 7, 25, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1516, 57, 7, 27, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1517, 57, 34, 173, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1518, 57, 34, 170, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1519, 57, 34, 171, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1520, 57, 34, 172, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1521, 57, 13, 50, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1522, 57, 13, 49, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1523, 57, 13, 52, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1524, 57, 13, 51, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1525, 57, 12, 46, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1526, 57, 12, 48, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1527, 57, 12, 45, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1528, 57, 12, 47, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1529, 57, 6, 22, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1530, 57, 6, 24, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1531, 57, 6, 21, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1532, 57, 6, 23, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1533, 57, 32, 163, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1534, 57, 32, 164, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1535, 57, 32, 162, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1536, 57, 32, 165, NULL, NULL, '2025-05-28 13:10:53', '2025-05-28 13:10:53'),
(1537, 58, 26, 103, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1538, 58, 26, 101, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1539, 58, 26, 104, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1540, 58, 26, 102, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1541, 58, 45, 114, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1542, 58, 45, 116, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1543, 58, 45, 115, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1544, 58, 45, 117, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1545, 58, 46, 118, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1546, 58, 46, 119, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1547, 58, 46, 120, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1548, 58, 46, 121, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1549, 58, 18, 70, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1550, 58, 18, 72, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1551, 58, 18, 71, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1552, 58, 18, 69, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1553, 58, 1, 4, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1554, 58, 1, 1, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1555, 58, 1, 2, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1556, 58, 1, 3, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1557, 58, 24, 95, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1558, 58, 24, 94, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1559, 58, 24, 96, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1560, 58, 24, 93, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1561, 58, 49, 131, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1562, 58, 49, 133, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1563, 58, 49, 130, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1564, 58, 49, 132, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1565, 58, 16, 63, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1566, 58, 16, 64, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1567, 58, 16, 62, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1568, 58, 16, 61, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1569, 58, 27, 106, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1570, 58, 27, 108, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1571, 58, 27, 105, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1572, 58, 27, 107, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1573, 58, 25, 97, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1574, 58, 25, 100, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1575, 58, 25, 99, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1576, 58, 25, 98, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1577, 58, 51, 138, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1578, 58, 51, 139, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1579, 58, 51, 140, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1580, 58, 51, 141, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1581, 58, 44, 110, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1582, 58, 44, 113, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1583, 58, 44, 112, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1584, 58, 44, 111, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1585, 58, 35, 176, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1586, 58, 35, 177, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1587, 58, 35, 174, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1588, 58, 35, 175, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1589, 58, 7, 26, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1590, 58, 7, 25, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1591, 58, 7, 28, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1592, 58, 7, 27, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1593, 58, 10, 37, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1594, 58, 10, 40, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1595, 58, 10, 39, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1596, 58, 10, 38, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1597, 58, 36, 179, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1598, 58, 36, 180, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1599, 58, 36, 178, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1600, 58, 36, 181, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1601, 58, 39, 193, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1602, 58, 39, 190, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1603, 58, 39, 191, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1604, 58, 39, 192, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1605, 58, 33, 166, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1606, 58, 33, 169, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1607, 58, 33, 167, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1608, 58, 33, 168, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1609, 58, 5, 18, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1610, 58, 5, 20, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1611, 58, 5, 19, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1612, 58, 5, 17, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1613, 58, 38, 188, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1614, 58, 38, 187, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1615, 58, 38, 189, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1616, 58, 38, 186, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1617, 58, 30, 154, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1618, 58, 30, 156, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1619, 58, 30, 155, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1620, 58, 30, 157, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1621, 58, 9, 35, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1622, 58, 9, 33, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1623, 58, 9, 36, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1624, 58, 9, 34, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1625, 58, 8, 31, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1626, 58, 8, 32, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1627, 58, 8, 30, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1628, 58, 8, 29, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1629, 58, 3, 11, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1630, 58, 3, 12, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1631, 58, 3, 9, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1632, 58, 3, 10, NULL, NULL, '2025-05-28 13:11:09', '2025-05-28 13:11:09'),
(1633, 59, 49, 131, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1634, 59, 49, 132, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1635, 59, 49, 130, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1636, 59, 49, 133, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1637, 59, 20, 79, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1638, 59, 20, 77, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1639, 59, 20, 80, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1640, 59, 20, 78, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1641, 59, 46, 120, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1642, 59, 46, 118, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1643, 59, 46, 121, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1644, 59, 46, 119, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1645, 59, 47, 122, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1646, 59, 47, 124, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1647, 59, 47, 123, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1648, 59, 47, 125, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1649, 59, 1, 1, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1650, 59, 1, 2, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1651, 59, 1, 3, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1652, 59, 1, 4, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1653, 59, 17, 66, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1654, 59, 17, 68, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1655, 59, 17, 67, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1656, 59, 17, 65, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1657, 59, 23, 91, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1658, 59, 23, 90, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1659, 59, 23, 89, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1660, 59, 23, 92, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1661, 59, 51, 141, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1662, 59, 51, 138, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1663, 59, 51, 140, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1664, 59, 51, 139, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1665, 59, 44, 111, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1666, 59, 44, 110, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1667, 59, 44, 113, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1668, 59, 44, 112, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1669, 59, 22, 88, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1670, 59, 22, 86, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1671, 59, 22, 87, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1672, 59, 22, 85, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1673, 59, 50, 136, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1674, 59, 50, 137, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1675, 59, 50, 135, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1676, 59, 50, 134, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1677, 59, 26, 103, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1678, 59, 26, 101, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1679, 59, 26, 104, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1680, 59, 26, 102, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1681, 59, 5, 18, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1682, 59, 5, 20, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1683, 59, 5, 17, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1684, 59, 5, 19, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1685, 59, 15, 58, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1686, 59, 15, 60, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1687, 59, 15, 57, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1688, 59, 15, 59, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1689, 59, 8, 31, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1690, 59, 8, 29, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1691, 59, 8, 32, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1692, 59, 8, 30, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1693, 59, 39, 190, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1694, 59, 39, 193, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1695, 59, 39, 191, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1696, 59, 39, 192, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1697, 59, 4, 16, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1698, 59, 4, 15, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1699, 59, 4, 13, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1700, 59, 4, 14, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1701, 59, 29, 151, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1702, 59, 29, 153, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1703, 59, 29, 152, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1704, 59, 29, 150, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1705, 59, 14, 56, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1706, 59, 14, 53, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1707, 59, 14, 55, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1708, 59, 14, 54, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1709, 59, 30, 156, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1710, 59, 30, 154, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1711, 59, 30, 157, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1712, 59, 30, 155, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1713, 59, 13, 51, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1714, 59, 13, 49, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1715, 59, 13, 50, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1716, 59, 13, 52, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1717, 59, 37, 184, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1718, 59, 37, 183, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1719, 59, 37, 182, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1720, 59, 37, 185, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1721, 59, 38, 187, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1722, 59, 38, 189, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1723, 59, 38, 186, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1724, 59, 38, 188, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1725, 59, 11, 44, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1726, 59, 11, 42, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1727, 59, 11, 43, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1728, 59, 11, 41, NULL, NULL, '2025-05-28 13:11:17', '2025-05-28 13:11:17'),
(1729, 60, 18, 70, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1730, 60, 18, 69, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1731, 60, 18, 71, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1732, 60, 18, 72, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1733, 60, 50, 136, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1734, 60, 50, 134, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1735, 60, 50, 135, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1736, 60, 50, 137, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1737, 60, 24, 94, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1738, 60, 24, 96, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1739, 60, 24, 93, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1740, 60, 24, 95, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1741, 60, 1, 3, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1742, 60, 1, 1, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1743, 60, 1, 4, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1744, 60, 1, 2, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1745, 60, 44, 111, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1746, 60, 44, 112, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1747, 60, 44, 113, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1748, 60, 44, 110, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1749, 60, 22, 86, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1750, 60, 22, 87, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1751, 60, 22, 88, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1752, 60, 22, 85, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1753, 60, 51, 140, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1754, 60, 51, 138, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1755, 60, 51, 139, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1756, 60, 51, 141, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1757, 60, 2, 7, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1758, 60, 2, 6, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1759, 60, 2, 8, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1760, 60, 2, 5, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1761, 60, 19, 74, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1762, 60, 19, 76, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1763, 60, 19, 73, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1764, 60, 19, 75, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1765, 60, 49, 131, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1766, 60, 49, 132, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1767, 60, 49, 133, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1768, 60, 49, 130, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1769, 60, 46, 120, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1770, 60, 46, 118, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1771, 60, 46, 121, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1772, 60, 46, 119, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1773, 60, 23, 91, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1774, 60, 23, 92, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1775, 60, 23, 90, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1776, 60, 23, 89, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1777, 60, 31, 158, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1778, 60, 31, 159, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1779, 60, 31, 160, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1780, 60, 31, 161, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1781, 60, 34, 171, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1782, 60, 34, 170, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1783, 60, 34, 172, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1784, 60, 34, 173, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1785, 60, 29, 152, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1786, 60, 29, 150, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1787, 60, 29, 153, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1788, 60, 29, 151, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1789, 60, 39, 192, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1790, 60, 39, 193, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1791, 60, 39, 191, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1792, 60, 39, 190, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1793, 60, 36, 178, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1794, 60, 36, 181, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1795, 60, 36, 179, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1796, 60, 36, 180, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1797, 60, 28, 149, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1798, 60, 28, 146, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1799, 60, 28, 148, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1800, 60, 28, 147, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1801, 60, 4, 15, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1802, 60, 4, 13, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1803, 60, 4, 14, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1804, 60, 4, 16, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1805, 60, 3, 9, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1806, 60, 3, 11, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1807, 60, 3, 10, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1808, 60, 3, 12, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1809, 60, 35, 174, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1810, 60, 35, 176, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1811, 60, 35, 177, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1812, 60, 35, 175, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1813, 60, 5, 19, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1814, 60, 5, 17, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1815, 60, 5, 20, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1816, 60, 5, 18, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1817, 60, 11, 42, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1818, 60, 11, 44, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1819, 60, 11, 43, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1820, 60, 11, 41, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1821, 60, 12, 46, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1822, 60, 12, 45, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1823, 60, 12, 47, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1824, 60, 12, 48, NULL, NULL, '2025-05-28 22:57:22', '2025-05-28 22:57:22'),
(1825, 61, 26, 103, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1826, 61, 26, 101, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1827, 61, 26, 102, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1828, 61, 26, 104, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1829, 61, 20, 79, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1830, 61, 20, 80, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1831, 61, 20, 77, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1832, 61, 20, 78, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1833, 61, 24, 94, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1834, 61, 24, 93, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1835, 61, 24, 96, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1836, 61, 24, 95, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1837, 61, 51, 138, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1838, 61, 51, 139, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1839, 61, 51, 141, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1840, 61, 51, 140, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1841, 61, 2, 6, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1842, 61, 2, 7, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1843, 61, 2, 5, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1844, 61, 2, 8, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1845, 61, 50, 134, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1846, 61, 50, 136, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1847, 61, 50, 137, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1848, 61, 50, 135, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1849, 61, 16, 63, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1850, 61, 16, 64, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1851, 61, 16, 61, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1852, 61, 16, 62, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1853, 61, 49, 133, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1854, 61, 49, 131, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1855, 61, 49, 130, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1856, 61, 49, 132, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1857, 61, 47, 123, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1858, 61, 47, 124, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1859, 61, 47, 122, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1860, 61, 47, 125, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1861, 61, 25, 100, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1862, 61, 25, 97, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1863, 61, 25, 99, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1864, 61, 25, 98, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1865, 61, 48, 127, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1866, 61, 48, 128, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1867, 61, 48, 129, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1868, 61, 48, 126, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1869, 61, 44, 111, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1870, 61, 44, 113, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1871, 61, 44, 110, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1872, 61, 44, 112, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1873, 61, 14, 55, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1874, 61, 14, 56, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1875, 61, 14, 53, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1876, 61, 14, 54, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1877, 61, 32, 165, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1878, 61, 32, 164, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1879, 61, 32, 163, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1880, 61, 32, 162, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1881, 61, 31, 161, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1882, 61, 31, 159, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1883, 61, 31, 158, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1884, 61, 31, 160, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1885, 61, 10, 37, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1886, 61, 10, 38, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1887, 61, 10, 39, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1888, 61, 10, 40, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1889, 61, 39, 192, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1890, 61, 39, 193, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1891, 61, 39, 190, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1892, 61, 39, 191, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1893, 61, 9, 33, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1894, 61, 9, 34, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1895, 61, 9, 35, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1896, 61, 9, 36, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1897, 61, 30, 154, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1898, 61, 30, 157, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1899, 61, 30, 155, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1900, 61, 30, 156, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1901, 61, 5, 20, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1902, 61, 5, 19, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1903, 61, 5, 17, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1904, 61, 5, 18, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1905, 61, 11, 43, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1906, 61, 11, 44, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1907, 61, 11, 41, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1908, 61, 11, 42, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1909, 61, 29, 153, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1910, 61, 29, 151, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1911, 61, 29, 152, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1912, 61, 29, 150, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1913, 61, 13, 52, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1914, 61, 13, 49, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1915, 61, 13, 51, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1916, 61, 13, 50, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1917, 61, 35, 174, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1918, 61, 35, 175, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1919, 61, 35, 177, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1920, 61, 35, 176, NULL, NULL, '2025-05-28 22:58:18', '2025-05-28 22:58:18'),
(1921, 62, 21, 82, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1922, 62, 21, 83, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1923, 62, 21, 84, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1924, 62, 21, 81, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1925, 62, 24, 93, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1926, 62, 24, 94, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1927, 62, 24, 95, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1928, 62, 24, 96, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1929, 62, 23, 90, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1930, 62, 23, 91, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1931, 62, 23, 89, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1932, 62, 23, 92, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1933, 62, 47, 125, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1934, 62, 47, 124, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1935, 62, 47, 123, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1936, 62, 47, 122, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1937, 62, 17, 67, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1938, 62, 17, 65, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1939, 62, 17, 68, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1940, 62, 17, 66, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1941, 62, 16, 61, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1942, 62, 16, 64, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1943, 62, 16, 63, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1944, 62, 16, 62, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1945, 62, 48, 126, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1946, 62, 48, 129, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1947, 62, 48, 128, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1948, 62, 48, 127, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1949, 62, 26, 101, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1950, 62, 26, 103, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1951, 62, 26, 104, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1952, 62, 26, 102, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1953, 62, 46, 119, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1954, 62, 46, 118, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1955, 62, 46, 120, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1956, 62, 46, 121, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1957, 62, 18, 72, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1958, 62, 18, 69, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1959, 62, 18, 71, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1960, 62, 18, 70, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1961, 62, 50, 137, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1962, 62, 50, 134, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1963, 62, 50, 135, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1964, 62, 50, 136, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1965, 62, 20, 80, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1966, 62, 20, 77, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1967, 62, 20, 78, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1968, 62, 20, 79, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1969, 62, 28, 147, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1970, 62, 28, 148, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1971, 62, 28, 149, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1972, 62, 28, 146, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1973, 62, 14, 55, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1974, 62, 14, 53, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1975, 62, 14, 54, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1976, 62, 14, 56, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1977, 62, 3, 9, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1978, 62, 3, 11, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1979, 62, 3, 10, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1980, 62, 3, 12, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1981, 62, 5, 18, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1982, 62, 5, 20, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1983, 62, 5, 17, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1984, 62, 5, 19, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1985, 62, 31, 158, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1986, 62, 31, 161, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1987, 62, 31, 159, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1988, 62, 31, 160, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1989, 62, 12, 48, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1990, 62, 12, 45, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1991, 62, 12, 46, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1992, 62, 12, 47, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1993, 62, 39, 191, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1994, 62, 39, 192, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1995, 62, 39, 193, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1996, 62, 39, 190, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1997, 62, 30, 154, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1998, 62, 30, 156, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(1999, 62, 30, 155, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(2000, 62, 30, 157, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(2001, 62, 11, 42, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(2002, 62, 11, 43, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(2003, 62, 11, 41, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(2004, 62, 11, 44, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(2005, 62, 38, 187, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(2006, 62, 38, 188, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(2007, 62, 38, 186, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(2008, 62, 38, 189, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(2009, 62, 35, 176, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(2010, 62, 35, 174, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(2011, 62, 35, 177, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(2012, 62, 35, 175, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(2013, 62, 9, 33, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(2014, 62, 9, 35, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38');
INSERT INTO `test_details` (`pk_testdetail`, `test_fk`, `title_fk`, `question_fk`, `answer_fk`, `ai_comments`, `created_at`, `updated_at`) VALUES
(2015, 62, 9, 34, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(2016, 62, 9, 36, NULL, NULL, '2025-05-28 23:20:38', '2025-05-28 23:20:38'),
(2017, 63, 18, 70, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2018, 63, 18, 72, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2019, 63, 18, 69, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2020, 63, 18, 71, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2021, 63, 45, 116, 469, NULL, '2025-06-07 13:12:18', '2025-06-07 13:14:19'),
(2022, 63, 45, 114, 461, NULL, '2025-06-07 13:12:18', '2025-06-07 13:14:19'),
(2023, 63, 45, 117, 473, NULL, '2025-06-07 13:12:18', '2025-06-07 13:14:19'),
(2024, 63, 45, 115, 464, NULL, '2025-06-07 13:12:18', '2025-06-07 13:14:19'),
(2025, 63, 21, 82, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2026, 63, 21, 81, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2027, 63, 21, 84, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2028, 63, 21, 83, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2029, 63, 49, 132, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2030, 63, 49, 130, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2031, 63, 49, 131, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2032, 63, 49, 133, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2033, 63, 51, 140, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2034, 63, 51, 141, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2035, 63, 51, 138, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2036, 63, 51, 139, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2037, 63, 46, 118, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2038, 63, 46, 119, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2039, 63, 46, 120, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2040, 63, 46, 121, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2041, 63, 27, 105, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2042, 63, 27, 107, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2043, 63, 27, 106, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2044, 63, 27, 108, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2045, 63, 26, 104, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2046, 63, 26, 101, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2047, 63, 26, 103, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2048, 63, 26, 102, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2049, 63, 23, 90, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2050, 63, 23, 92, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2051, 63, 23, 91, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2052, 63, 23, 89, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2053, 63, 50, 135, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2054, 63, 50, 136, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2055, 63, 50, 137, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2056, 63, 50, 134, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2057, 63, 19, 76, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2058, 63, 19, 75, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2059, 63, 19, 73, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2060, 63, 19, 74, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2061, 63, 20, 77, 316, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"El contexto proporcionado indica que \'All staff\' (todo el personal) está obligado a completar la capacitación en seguridad en línea para fin de mes, no solo los nuevos empleados.\"], \"sugerencias\": [\"Para responder correctamente, es importante prestar atención a los detalles específicos mencionados en el contexto. En este caso, \'All staff\' claramente incluye a todo el personal, no solo a los nuevos empleados.\"]}', '2025-06-07 13:12:18', '2025-06-16 22:58:06'),
(2062, 63, 20, 79, 325, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"La respuesta correcta es \'By the end of the month\' porque el contexto establece claramente que \'All staff are required to complete the online security training by the end of the month\'.\"], \"sugerencias\": [\"Asegúrate de leer cuidadosamente el contexto para identificar plazos específicos.\", \"Practica identificando palabras clave que indican tiempo, como \'by the end of the month\'.\"]}', '2025-06-07 13:12:18', '2025-06-16 22:59:20'),
(2063, 63, 20, 80, 326, '{\"evaluacion\": \"correcta\", \"explicacion\": [\"La respuesta \'A company memo\' es correcta porque el contexto proporcionado es típico de un memorándum interno de una empresa, que informa a los empleados sobre un requisito de capacitación en seguridad en línea.\"], \"sugerencias\": [\"Para mejorar la comprensión, podrías mencionar características específicas de un memo, como su formato o propósito común dentro de una organización.\"]}', '2025-06-07 13:12:18', '2025-06-16 23:00:18'),
(2064, 63, 20, 78, 319, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"La respuesta correcta es \'Online security training\' ya que es el tipo de entrenamiento mencionado en el contexto proporcionado.\"], \"sugerencias\": [\"Asegúrate de leer cuidadosamente el contexto para identificar la información relevante antes de responder.\", \"Practica identificando palabras clave en el texto que te ayuden a encontrar la respuesta correcta.\"]}', '2025-06-07 13:12:18', '2025-06-16 22:59:01'),
(2065, 63, 32, 164, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2066, 63, 32, 165, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2067, 63, 32, 162, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2068, 63, 32, 163, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2069, 63, 6, 24, 103, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"La respuesta del estudiante \'Prescribe medicine\' no coincide con la acción mencionada por Speaker A en el contexto proporcionado, que es \'Let\'s take a look\'.\", \"El contexto claramente indica que Speaker A propone examinar (take a look) a Speaker B, no prescribir medicina.\"], \"sugerencias\": [\"Para mejorar, el estudiante debe prestar más atención a las palabras clave en el diálogo que indican la acción inmediata a realizar.\", \"Es útil practicar con diálogos similares para familiarizarse con frases comunes en contextos médicos, como \'take a look\', \'examine\', etc.\"]}', '2025-06-07 13:12:18', '2025-06-16 22:44:41'),
(2070, 63, 6, 21, 90, '{\"evaluacion\": \"correcta\", \"explicacion\": [\"La respuesta del estudiante coincide exactamente con la respuesta correcta proporcionada en el contexto.\", \"El estudiante ha identificado correctamente los síntomas mencionados por el paciente en el diálogo.\"], \"sugerencias\": [\"Aunque la respuesta es correcta, se podría mejorar la precisión incluyendo artículos, por ejemplo: \'A sore throat and a fever\'.\", \"Practicar la escucha de diálogos similares para mejorar la capacidad de identificar información específica en contextos médicos.\"]}', '2025-06-07 13:12:18', '2025-06-16 22:43:15'),
(2071, 63, 6, 23, 99, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"La respuesta del estudiante \'In a hospital room\' no coincide con el contexto proporcionado, donde se menciona síntomas comunes y una respuesta típica de un profesional de la salud (\'Let\'s take a look\'), lo cual es más característico de una consulta en un consultorio médico que en una habitación de hospital.\", \"La respuesta correcta \'In a doctor\'s office\' se alinea mejor con el escenario descrito, ya que la interacción es breve y directa, típica de una consulta inicial en un consultorio.\"], \"sugerencias\": [\"Para mejorar, el estudiante debería prestar atención a las pistas contextuales como la naturaleza de la conversación y las frases utilizadas, que pueden indicar el escenario más probable.\", \"Practicar con diálogos similares y familiarizarse con los contextos típicos de las conversaciones en inglés, especialmente aquellos relacionados con salud y consultas médicas, puede ayudar a identificar el lugar correcto con mayor precisión.\"]}', '2025-06-07 13:12:18', '2025-06-16 22:44:14'),
(2072, 63, 6, 22, 95, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"La respuesta del estudiante identifica a Speaker A como \'A nurse\' (enfermera), pero la respuesta correcta es \'A doctor\' (médico).\", \"En el contexto médico proporcionado, es más probable que Speaker A sea un médico ya que está realizando un diagnóstico inicial (\'Let\'s take a look\') lo cual es típico de un doctor.\"], \"sugerencias\": [\"Para mejorar, el estudiante debería prestar atención a las pistas contextuales que indican el rol profesional de los hablantes.\", \"Es útil familiarizarse con escenarios comunes en el TOEIC, como consultas médicas, para reconocer más fácilmente los roles de los hablantes.\"]}', '2025-06-07 13:12:18', '2025-06-16 22:43:46'),
(2073, 63, 5, 17, 76, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"La respuesta del estudiante \'Chicken sandwich\' no coincide con la respuesta correcta \'Cheeseburger and fries\'.\", \"El estudiante no identificó correctamente el pedido del cliente según la pregunta.\"], \"sugerencias\": [\"Revisar cuidadosamente la información proporcionada en la pregunta para identificar detalles clave.\", \"Practicar con ejercicios de escucha o lectura que mejoren la capacidad de captar información específica.\"]}', '2025-06-07 13:12:18', '2025-06-16 22:11:42'),
(2074, 63, 5, 20, 86, '{\"evaluacion\": \"correcta\", \"explicacion\": [\"La respuesta del estudiante coincide exactamente con la respuesta correcta proporcionada.\", \"El contexto muestra que [SPEAKER_B] pregunta \'Would you like a drink with that?\', lo cual se traduce directamente a \'If they want a drink\' en el contexto de la pregunta.\"], \"sugerencias\": [\"Para mejorar, el estudiante podría practicar la identificación de preguntas similares en diferentes contextos para asegurar la comprensión en diversas situaciones.\", \"Se sugiere también practicar la escucha activa para captar detalles específicos en conversaciones, lo que puede ser útil en preguntas más detalladas o complejas.\"]}', '2025-06-07 13:12:18', '2025-06-16 22:38:07'),
(2075, 63, 5, 19, 83, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"La respuesta del estudiante \'At a grocery store\' no coincide con la respuesta correcta \'At a restaurant\'. Esto indica una posible falta de comprensión del contexto de la conversación en el examen TOEIC.\"], \"sugerencias\": [\"Revisar vocabulario y frases comunes utilizadas en restaurantes para mejorar la identificación del contexto.\", \"Practicar con audios de conversaciones en diferentes entornos para familiarizarse con los contextos típicos del examen TOEIC.\"]}', '2025-06-07 13:12:18', '2025-06-16 22:02:43'),
(2076, 63, 5, 18, 79, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"La respuesta del estudiante \'Water\' no coincide con la respuesta correcta \'Soda\'.\"], \"sugerencias\": [\"Presta atención a los detalles específicos mencionados en la conversación o texto.\", \"Practica la escucha activa para mejorar la comprensión de las órdenes o preferencias expresadas.\"]}', '2025-06-07 13:12:18', '2025-06-16 22:11:12'),
(2077, 63, 31, 160, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2078, 63, 31, 158, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2079, 63, 31, 159, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2080, 63, 31, 161, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2081, 63, 38, 188, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2082, 63, 38, 186, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2083, 63, 38, 189, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2084, 63, 38, 187, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2085, 63, 28, 149, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2086, 63, 28, 148, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2087, 63, 28, 146, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2088, 63, 28, 147, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2089, 63, 12, 45, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2090, 63, 12, 47, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2091, 63, 12, 48, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2092, 63, 12, 46, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2093, 63, 30, 155, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2094, 63, 30, 156, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2095, 63, 30, 154, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2096, 63, 30, 157, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2097, 63, 9, 36, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2098, 63, 9, 35, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2099, 63, 9, 34, 143, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"El huésped menciona claramente \'I\'d like to book a room for two nights\', lo que indica que desea quedarse dos noches.\"], \"sugerencias\": [\"Presta atención a los detalles específicos mencionados en la conversación para responder con precisión.\"]}', '2025-06-07 13:12:18', '2025-06-16 22:52:49'),
(2100, 63, 9, 33, 138, '{\"evaluacion\": \"correcta\", \"explicacion\": [\"El huésped claramente solicita una habitación doble cuando dice \'A double, please\' en respuesta a la pregunta sobre su preferencia entre una habitación individual o doble.\"], \"sugerencias\": [\"Para mejorar la comprensión, asegúrate de prestar atención a las palabras clave como \'double\' que indican el tipo de habitación solicitada.\"]}', '2025-06-07 13:12:18', '2025-06-16 23:01:07'),
(2101, 63, 34, 171, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2102, 63, 34, 173, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2103, 63, 34, 172, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2104, 63, 34, 170, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2105, 63, 8, 31, 132, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"Anna no pregunta \'¿Quién llama?\', sino que responde con \'Yes, speaking\', lo que indica que está confirmando su identidad y está lista para escuchar.\"], \"sugerencias\": [\"Para mejorar la comprensión, presta atención a las respuestas directas y confirmaciones en las conversaciones telefónicas.\"]}', '2025-06-07 13:12:18', '2025-06-16 23:37:54'),
(2106, 63, 8, 32, 135, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"El propósito de la llamada no se especifica claramente en la conversación proporcionada. Solo se menciona que John de HR está llamando, pero no se da información sobre el motivo específico de la llamada.\"], \"sugerencias\": [\"Para mejorar la comprensión, sería útil incluir más contexto o detalles sobre el motivo de la llamada en la conversación.\"]}', '2025-06-07 13:12:18', '2025-06-16 23:38:05'),
(2107, 63, 8, 30, 128, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"La respuesta correcta es \'HR\' porque en el contexto proporcionado, [SPEAKER_A] se identifica como \'John from HR\', lo que indica que John trabaja en el departamento de Recursos Humanos.\"], \"sugerencias\": [\"Presta atención a los detalles específicos mencionados en el diálogo para identificar correctamente la información solicitada.\"]}', '2025-06-07 13:12:18', '2025-06-16 22:52:19'),
(2108, 63, 8, 29, 122, '{\"evaluacion\": \"correcta\", \"explicacion\": [\"La respuesta proporcionada coincide con la información dada en el contexto, donde [SPEAKER_A] se identifica como \'John from HR\'.\"], \"sugerencias\": [\"Asegúrate de siempre verificar el contexto para confirmar la exactitud de la información antes de responder.\"]}', '2025-06-07 13:12:18', '2025-06-16 22:51:53'),
(2109, 63, 33, 166, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2110, 63, 33, 168, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2111, 63, 33, 167, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2112, 63, 33, 169, NULL, NULL, '2025-06-07 13:12:18', '2025-06-07 13:12:18'),
(2113, 64, 27, 107, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2114, 64, 27, 106, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2115, 64, 27, 105, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2116, 64, 27, 108, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2117, 64, 19, 73, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2118, 64, 19, 75, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2119, 64, 19, 74, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2120, 64, 19, 76, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2121, 64, 20, 80, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2122, 64, 20, 79, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2123, 64, 20, 77, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2124, 64, 20, 78, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2125, 64, 2, 8, 29, NULL, '2025-06-16 23:24:45', '2025-06-16 23:25:23'),
(2126, 64, 2, 6, 21, NULL, '2025-06-16 23:24:45', '2025-06-16 23:25:23'),
(2127, 64, 2, 5, 17, NULL, '2025-06-16 23:24:45', '2025-06-16 23:25:23'),
(2128, 64, 2, 7, 25, NULL, '2025-06-16 23:24:45', '2025-06-16 23:25:23'),
(2129, 64, 23, 92, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2130, 64, 23, 89, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2131, 64, 23, 91, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2132, 64, 23, 90, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2133, 64, 17, 68, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2134, 64, 17, 66, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2135, 64, 17, 65, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2136, 64, 17, 67, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2137, 64, 48, 126, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2138, 64, 48, 128, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2139, 64, 48, 129, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2140, 64, 48, 127, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2141, 64, 24, 95, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2142, 64, 24, 96, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2143, 64, 24, 94, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2144, 64, 24, 93, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2145, 64, 46, 118, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2146, 64, 46, 121, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2147, 64, 46, 119, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2148, 64, 46, 120, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2149, 64, 1, 3, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2150, 64, 1, 2, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2151, 64, 1, 4, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2152, 64, 1, 1, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2153, 64, 52, 144, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2154, 64, 52, 143, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2155, 64, 52, 142, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2156, 64, 52, 145, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2157, 64, 47, 124, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2158, 64, 47, 123, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2159, 64, 47, 125, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2160, 64, 47, 122, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2161, 64, 7, 27, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2162, 64, 7, 28, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2163, 64, 7, 25, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2164, 64, 7, 26, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2165, 64, 35, 174, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2166, 64, 35, 176, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2167, 64, 35, 177, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2168, 64, 35, 175, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2169, 64, 36, 179, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2170, 64, 36, 180, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2171, 64, 36, 181, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2172, 64, 36, 178, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2173, 64, 5, 18, 79, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"El cliente no ordenó agua, sino un refresco (soda).\"], \"sugerencias\": [\"Presta atención a los detalles específicos mencionados en la conversación para identificar correctamente lo que el cliente ordena.\"]}', '2025-06-16 23:24:45', '2025-06-16 23:27:06'),
(2174, 64, 5, 20, 87, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"La pregunta del servidor fue \'Would you like a drink with that?\', lo que se traduce como \'¿Quieres una bebida con eso?\'. La opción correcta es \'If they want a drink\'.\"], \"sugerencias\": [\"Asegúrate de leer cuidadosamente el diálogo para identificar la pregunta exacta del servidor.\", \"Practica con diálogos similares para mejorar tu comprensión auditiva y de lectura en inglés.\"]}', '2025-06-16 23:24:45', '2025-06-17 13:48:21'),
(2175, 64, 5, 19, 83, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"La conversación gira en torno a pedir una hamburguesa con queso, papas fritas y una soda, lo cual es típico de un menú en un restaurante, no en una tienda de comestibles.\"], \"sugerencias\": [\"Considera el contexto de pedir comida preparada, que es más común en un restaurante que en una tienda de comestibles.\"]}', '2025-06-16 23:24:45', '2025-06-16 23:27:22'),
(2176, 64, 5, 17, 75, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"La respuesta correcta es \'Cheeseburger and fries\' porque el cliente claramente menciona \'I\'d like a cheeseburger and fries\' en el diálogo.\"], \"sugerencias\": [\"Presta atención a los detalles específicos mencionados en el diálogo para identificar correctamente lo que el cliente ordena.\"]}', '2025-06-16 23:24:45', '2025-06-16 23:26:56'),
(2177, 64, 8, 30, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2178, 64, 8, 29, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2179, 64, 8, 32, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2180, 64, 8, 31, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2181, 64, 37, 182, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2182, 64, 37, 183, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2183, 64, 37, 184, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2184, 64, 37, 185, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2185, 64, 10, 38, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2186, 64, 10, 39, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2187, 64, 10, 40, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2188, 64, 10, 37, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2189, 64, 28, 148, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2190, 64, 28, 147, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2191, 64, 28, 149, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2192, 64, 28, 146, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2193, 64, 31, 159, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2194, 64, 31, 160, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2195, 64, 31, 161, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2196, 64, 31, 158, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2197, 64, 3, 10, 46, '{\"evaluacion\": \"correcta\", \"explicacion\": [\"El cliente especifica que quiere su café \'Just black, please\', lo que significa que no desea ni crema ni azúcar.\"], \"sugerencias\": [\"Asegúrate de prestar atención a los detalles específicos que los clientes mencionan sobre sus preferencias para evitar errores en la preparación de sus pedidos.\"]}', '2025-06-16 23:24:45', '2025-06-21 12:47:52'),
(2198, 64, 3, 9, 42, '{\"evaluacion\": \"correcta\", \"explicacion\": [\"El cliente pide un café grande, como se menciona en la frase \'Hi, can I get a large coffee?\'\"], \"sugerencias\": [\"Asegúrate de prestar atención a los detalles específicos como tamaños y preferencias en las órdenes para responder correctamente.\"]}', '2025-06-16 23:24:45', '2025-06-16 23:26:01'),
(2199, 64, 3, 11, 50, '{\"evaluacion\": \"correcta\", \"explicacion\": [\"La conversación gira en torno a la compra de un café grande y las preferencias sobre cómo servirlo, lo cual es típico de una interacción en una cafetería.\"], \"sugerencias\": []}', '2025-06-16 23:24:45', '2025-06-16 23:26:26'),
(2200, 64, 3, 12, 54, NULL, '2025-06-16 23:24:45', '2025-06-16 23:25:23'),
(2201, 64, 34, 170, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2202, 64, 34, 171, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2203, 64, 34, 173, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2204, 64, 34, 172, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2205, 64, 14, 53, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2206, 64, 14, 56, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2207, 64, 14, 54, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2208, 64, 14, 55, NULL, NULL, '2025-06-16 23:24:45', '2025-06-16 23:24:45'),
(2209, 65, 51, 139, 562, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"La respuesta correcta es \'A big impact on the environment\' porque el texto menciona que \'Small changes can have a big impact on the environment\'. La opción \'Only a local impact\' no se menciona ni se implica en el contexto proporcionado.\"], \"sugerencias\": [\"Para mejorar la comprensión, es útil prestar atención a las palabras clave en el texto que directamente apoyan la respuesta correcta, como \'big impact\' en este caso.\"]}', '2025-06-16 23:38:48', '2025-06-17 00:05:27'),
(2210, 65, 51, 140, 565, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"La recomendación de usar bolsas reutilizables es más aplicable cuando se está comprando, no en casa. El contexto proporcionado menciona específicamente \'when shopping\' (al hacer compras), lo que indica que es en ese momento cuando se puede reducir el desperdicio utilizando bolsas reutilizables.\"], \"sugerencias\": [\"Para mejorar la precisión de la respuesta, considera el contexto dado en la pregunta. En este caso, el énfasis está en las acciones que se pueden tomar mientras se hacen compras para reducir el desperdicio.\"]}', '2025-06-16 23:38:48', '2025-06-16 23:49:22'),
(2211, 65, 51, 141, 568, '{\"evaluacion\": \"correcta\", \"explicacion\": [\"La respuesta \'To reduce waste\' es correcta porque el consejo ambiental mencionado tiene como objetivo principal reducir el desperdicio, específicamente al sugerir el uso de bolsas reutilizables al hacer compras.\"], \"sugerencias\": [\"Asegúrate de leer cuidadosamente el contexto proporcionado para identificar claramente el propósito o la intención detrás del consejo o información dada.\"]}', '2025-06-16 23:38:48', '2025-06-16 23:49:18'),
(2212, 65, 51, 138, 558, NULL, '2025-06-16 23:38:48', '2025-06-16 23:39:22'),
(2213, 65, 23, 92, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2214, 65, 23, 89, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2215, 65, 23, 90, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2216, 65, 23, 91, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2217, 65, 20, 78, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2218, 65, 20, 77, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2219, 65, 20, 80, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2220, 65, 20, 79, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2221, 65, 47, 124, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2222, 65, 47, 123, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2223, 65, 47, 122, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2224, 65, 47, 125, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2225, 65, 27, 105, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2226, 65, 27, 107, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2227, 65, 27, 106, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2228, 65, 27, 108, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2229, 65, 52, 145, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2230, 65, 52, 143, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2231, 65, 52, 142, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2232, 65, 52, 144, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2233, 65, 18, 69, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2234, 65, 18, 71, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2235, 65, 18, 72, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2236, 65, 18, 70, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2237, 65, 21, 82, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2238, 65, 21, 81, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2239, 65, 21, 83, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2240, 65, 21, 84, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2241, 65, 19, 73, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2242, 65, 19, 75, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2243, 65, 19, 74, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2244, 65, 19, 76, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2245, 65, 25, 99, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2246, 65, 25, 100, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2247, 65, 25, 98, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2248, 65, 25, 97, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2249, 65, 44, 112, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2250, 65, 44, 113, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2251, 65, 44, 110, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2252, 65, 44, 111, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2253, 65, 24, 96, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2254, 65, 24, 95, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2255, 65, 24, 93, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2256, 65, 24, 94, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2257, 65, 5, 20, 87, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"La respuesta correcta es \'If they want a drink\' porque en el diálogo, [SPEAKER_B] pregunta \'Would you like a drink with that?\', lo cual se traduce como \'¿Quieres una bebida con eso?\'\"], \"sugerencias\": [\"Presta atención a las palabras clave en el diálogo que indican lo que se está preguntando. En este caso, \'drink\' es la palabra clave que indica que la pregunta es sobre una bebida, no sobre un postre.\"]}', '2025-06-16 23:38:48', '2025-06-17 00:04:33'),
(2258, 65, 5, 18, 80, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"El cliente no ordenó café, sino un refresco (soda).\"], \"sugerencias\": [\"Presta atención a los detalles específicos mencionados en la conversación para identificar correctamente lo que el cliente ordena.\"]}', '2025-06-16 23:38:48', '2025-06-16 23:40:29'),
(2259, 65, 5, 19, 84, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"La conversación gira en torno a un pedido de comida, específicamente un cheeseburger y fries, seguido de una pregunta sobre si desea una bebida. Este tipo de interacción es típica de un entorno de servicio de comida, como un restaurante, no de una conversación en casa.\"], \"sugerencias\": [\"Para mejorar la comprensión, considera el contexto de pedidos de comida y bebidas, que es común en restaurantes o establecimientos de comida rápida, no en entornos domésticos.\"]}', '2025-06-16 23:38:48', '2025-06-16 23:40:40'),
(2260, 65, 5, 17, 77, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"La respuesta correcta es \'Cheeseburger and fries\' porque el cliente claramente menciona \'I\'d like a cheeseburger and fries\' en el diálogo.\"], \"sugerencias\": [\"Presta atención a los detalles específicos mencionados en el diálogo para identificar correctamente lo que el cliente ordena.\"]}', '2025-06-16 23:38:48', '2025-06-16 23:39:51'),
(2261, 65, 32, 164, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2262, 65, 32, 165, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2263, 65, 32, 163, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2264, 65, 32, 162, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2265, 65, 13, 50, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2266, 65, 13, 49, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2267, 65, 13, 52, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2268, 65, 13, 51, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2269, 65, 6, 22, 96, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"Speaker A is likely to be a doctor because they are responding to a medical complaint (\'a sore throat and a fever\') and suggest taking a look, which is a common phrase used by healthcare professionals when examining a patient.\"], \"sugerencias\": [\"Consider the context of the conversation, especially the nature of the symptoms mentioned and the response given, to identify the profession of Speaker A.\"]}', '2025-06-16 23:38:48', '2025-06-16 23:40:19'),
(2270, 65, 6, 24, 104, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"La respuesta correcta es \'Take a look\', ya que Speaker A menciona \'Let\'s take a look\' en respuesta a los síntomas presentados por Speaker B.\"], \"sugerencias\": [\"Presta atención a las frases clave en el diálogo que indican acciones futuras o intenciones.\", \"Practica identificar acciones propuestas o acordadas en conversaciones similares para mejorar tu comprensión.\"]}', '2025-06-16 23:38:48', '2025-06-16 23:40:07'),
(2271, 65, 6, 21, 91, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"La respuesta correcta es \'Sore throat and fever\' porque el paciente menciona específicamente \'I have a sore throat and a fever\' en el diálogo.\"], \"sugerencias\": [\"Para mejorar, presta atención a los detalles específicos mencionados en el diálogo. En este caso, el paciente no menciona \'headache\' (dolor de cabeza) ni \'cough\' (tos), sino \'sore throat\' (dolor de garganta) y \'fever\' (fiebre).\"]}', '2025-06-16 23:38:48', '2025-06-16 23:48:49'),
(2272, 65, 6, 23, 100, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"La respuesta correcta es \'In a doctor\'s office\' porque el contexto de la conversación sugiere que el hablante A está realizando un examen médico al hablante B, lo cual es típico de una consulta médica, no de una farmacia.\"], \"sugerencias\": [\"Para mejorar la comprensión, presta atención a las pistas contextuales como \'Let\'s take a look\', que indica un examen médico, común en consultorios médicos.\"]}', '2025-06-16 23:38:48', '2025-06-16 23:49:03'),
(2273, 65, 10, 38, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2274, 65, 10, 39, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2275, 65, 10, 40, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2276, 65, 10, 37, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2277, 65, 37, 185, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2278, 65, 37, 184, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2279, 65, 37, 183, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2280, 65, 37, 182, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2281, 65, 33, 166, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2282, 65, 33, 169, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2283, 65, 33, 167, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2284, 65, 33, 168, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2285, 65, 11, 44, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2286, 65, 11, 41, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2287, 65, 11, 43, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2288, 65, 11, 42, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2289, 65, 14, 54, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2290, 65, 14, 53, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2291, 65, 14, 55, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2292, 65, 14, 56, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2293, 65, 31, 158, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2294, 65, 31, 161, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2295, 65, 31, 159, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2296, 65, 31, 160, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2297, 65, 8, 30, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2298, 65, 8, 31, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2299, 65, 8, 29, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2300, 65, 8, 32, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2301, 65, 38, 189, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2302, 65, 38, 188, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2303, 65, 38, 187, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2304, 65, 38, 186, NULL, NULL, '2025-06-16 23:38:48', '2025-06-16 23:38:48'),
(2305, 66, 44, 111, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2306, 66, 44, 110, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2307, 66, 44, 112, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2308, 66, 44, 113, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2309, 66, 16, 64, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2310, 66, 16, 63, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2311, 66, 16, 61, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2312, 66, 16, 62, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2313, 66, 52, 145, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2314, 66, 52, 144, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2315, 66, 52, 142, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2316, 66, 52, 143, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2317, 66, 47, 124, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2318, 66, 47, 125, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2319, 66, 47, 123, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2320, 66, 47, 122, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2321, 66, 51, 138, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2322, 66, 51, 140, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2323, 66, 51, 139, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2324, 66, 51, 141, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2325, 66, 22, 88, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2326, 66, 22, 87, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2327, 66, 22, 85, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2328, 66, 22, 86, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2329, 66, 24, 95, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2330, 66, 24, 93, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2331, 66, 24, 94, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2332, 66, 24, 96, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2333, 66, 18, 72, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2334, 66, 18, 70, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2335, 66, 18, 69, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2336, 66, 18, 71, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2337, 66, 25, 97, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2338, 66, 25, 99, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2339, 66, 25, 100, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2340, 66, 25, 98, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2341, 66, 23, 90, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2342, 66, 23, 92, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2343, 66, 23, 89, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2344, 66, 23, 91, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2345, 66, 20, 77, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2346, 66, 20, 80, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2347, 66, 20, 79, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2348, 66, 20, 78, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2349, 66, 21, 83, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2350, 66, 21, 81, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2351, 66, 21, 82, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2352, 66, 21, 84, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2353, 66, 39, 193, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2354, 66, 39, 191, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2355, 66, 39, 192, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2356, 66, 39, 190, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2357, 66, 11, 43, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2358, 66, 11, 42, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2359, 66, 11, 44, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2360, 66, 11, 41, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2361, 66, 6, 22, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2362, 66, 6, 24, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2363, 66, 6, 21, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2364, 66, 6, 23, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2365, 66, 30, 156, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2366, 66, 30, 154, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2367, 66, 30, 155, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2368, 66, 30, 157, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2369, 66, 31, 161, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2370, 66, 31, 160, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2371, 66, 31, 159, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2372, 66, 31, 158, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2373, 66, 36, 179, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2374, 66, 36, 181, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2375, 66, 36, 180, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2376, 66, 36, 178, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2377, 66, 32, 165, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2378, 66, 32, 163, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2379, 66, 32, 164, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2380, 66, 32, 162, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2381, 66, 10, 39, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2382, 66, 10, 38, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2383, 66, 10, 40, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2384, 66, 10, 37, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2385, 66, 8, 32, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2386, 66, 8, 30, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2387, 66, 8, 29, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2388, 66, 8, 31, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2389, 66, 38, 187, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2390, 66, 38, 188, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2391, 66, 38, 189, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2392, 66, 38, 186, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2393, 66, 35, 177, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2394, 66, 35, 175, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2395, 66, 35, 176, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2396, 66, 35, 174, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2397, 66, 3, 11, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2398, 66, 3, 9, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2399, 66, 3, 10, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2400, 66, 3, 12, NULL, NULL, '2025-06-17 00:13:12', '2025-06-17 00:13:12'),
(2401, 67, 17, 65, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2402, 67, 17, 67, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2403, 67, 17, 68, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2404, 67, 17, 66, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2405, 67, 16, 61, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2406, 67, 16, 63, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2407, 67, 16, 64, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2408, 67, 16, 62, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2409, 67, 21, 83, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2410, 67, 21, 82, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2411, 67, 21, 84, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2412, 67, 21, 81, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2413, 67, 2, 5, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2414, 67, 2, 8, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2415, 67, 2, 6, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2416, 67, 2, 7, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2417, 67, 18, 70, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2418, 67, 18, 69, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2419, 67, 18, 71, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2420, 67, 18, 72, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2421, 67, 1, 1, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2422, 67, 1, 2, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2423, 67, 1, 4, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2424, 67, 1, 3, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2425, 67, 20, 77, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2426, 67, 20, 80, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2427, 67, 20, 79, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2428, 67, 20, 78, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2429, 67, 51, 138, 558, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:45'),
(2430, 67, 51, 141, 569, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"La respuesta correcta es \'To reduce waste\', ya que el consejo ambiental menciona específicamente \'Reduce waste by bringing reusable bags when shopping\', lo que indica que el propósito principal es reducir los desechos.\"], \"sugerencias\": [\"Para mejorar la comprensión, es útil prestar atención a las palabras clave en el texto, como \'reduce waste\' en este caso, que indican claramente el propósito del consejo.\"]}', '2025-06-17 00:23:29', '2025-06-17 02:06:53'),
(2431, 67, 51, 139, 561, '{\"evaluacion\": \"incorrecta\", \"explicacion\": [\"El texto menciona claramente que \'Small changes can have a big impact on the environment\', lo que contradice la respuesta seleccionada que afirma \'No significant impact\'.\"], \"sugerencias\": [\"Para mejorar la comprensión del texto, es importante prestar atención a los detalles específicos que se mencionan, como el efecto de los pequeños cambios en el medio ambiente.\"]}', '2025-06-17 00:23:29', '2025-06-17 00:24:35'),
(2432, 67, 51, 140, 565, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:45'),
(2433, 67, 19, 76, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2434, 67, 19, 75, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2435, 67, 19, 73, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2436, 67, 19, 74, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2437, 67, 24, 95, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2438, 67, 24, 96, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2439, 67, 24, 94, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2440, 67, 24, 93, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2441, 67, 46, 121, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2442, 67, 46, 118, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2443, 67, 46, 119, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2444, 67, 46, 120, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2445, 67, 25, 97, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29');
INSERT INTO `test_details` (`pk_testdetail`, `test_fk`, `title_fk`, `question_fk`, `answer_fk`, `ai_comments`, `created_at`, `updated_at`) VALUES
(2446, 67, 25, 99, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2447, 67, 25, 98, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2448, 67, 25, 100, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2449, 67, 14, 56, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2450, 67, 14, 55, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2451, 67, 14, 53, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2452, 67, 14, 54, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2453, 67, 38, 189, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2454, 67, 38, 188, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2455, 67, 38, 186, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2456, 67, 38, 187, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2457, 67, 30, 155, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2458, 67, 30, 156, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2459, 67, 30, 157, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2460, 67, 30, 154, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2461, 67, 10, 37, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2462, 67, 10, 39, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2463, 67, 10, 38, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2464, 67, 10, 40, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2465, 67, 33, 169, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2466, 67, 33, 167, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2467, 67, 33, 166, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2468, 67, 33, 168, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2469, 67, 13, 52, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2470, 67, 13, 49, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2471, 67, 13, 51, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2472, 67, 13, 50, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2473, 67, 29, 153, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2474, 67, 29, 152, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2475, 67, 29, 150, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2476, 67, 29, 151, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2477, 67, 31, 158, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2478, 67, 31, 161, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2479, 67, 31, 160, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2480, 67, 31, 159, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2481, 67, 8, 30, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2482, 67, 8, 32, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2483, 67, 8, 31, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2484, 67, 8, 29, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2485, 67, 15, 59, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2486, 67, 15, 60, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2487, 67, 15, 57, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2488, 67, 15, 58, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2489, 67, 32, 162, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2490, 67, 32, 163, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2491, 67, 32, 164, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2492, 67, 32, 165, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2493, 67, 34, 173, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2494, 67, 34, 171, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2495, 67, 34, 172, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2496, 67, 34, 170, NULL, NULL, '2025-06-17 00:23:29', '2025-06-17 00:23:29'),
(2497, 68, 2, 6, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2498, 68, 2, 7, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2499, 68, 2, 5, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2500, 68, 2, 8, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2501, 68, 51, 138, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2502, 68, 51, 140, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2503, 68, 51, 141, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2504, 68, 51, 139, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2505, 68, 21, 81, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2506, 68, 21, 82, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2507, 68, 21, 83, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2508, 68, 21, 84, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2509, 68, 45, 115, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2510, 68, 45, 117, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2511, 68, 45, 114, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2512, 68, 45, 116, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2513, 68, 23, 91, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2514, 68, 23, 92, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2515, 68, 23, 89, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2516, 68, 23, 90, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2517, 68, 26, 101, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2518, 68, 26, 104, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2519, 68, 26, 102, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2520, 68, 26, 103, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2521, 68, 47, 124, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2522, 68, 47, 122, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2523, 68, 47, 125, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2524, 68, 47, 123, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2525, 68, 22, 86, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2526, 68, 22, 88, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2527, 68, 22, 87, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2528, 68, 22, 85, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2529, 68, 52, 144, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2530, 68, 52, 145, 587, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:19'),
(2531, 68, 52, 143, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2532, 68, 52, 142, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2533, 68, 49, 131, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2534, 68, 49, 130, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2535, 68, 49, 133, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2536, 68, 49, 132, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2537, 68, 18, 72, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2538, 68, 18, 69, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2539, 68, 18, 70, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2540, 68, 18, 71, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2541, 68, 16, 63, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2542, 68, 16, 62, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2543, 68, 16, 61, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2544, 68, 16, 64, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2545, 68, 15, 60, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2546, 68, 15, 57, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2547, 68, 15, 58, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2548, 68, 15, 59, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2549, 68, 11, 43, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2550, 68, 11, 42, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2551, 68, 11, 44, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2552, 68, 11, 41, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2553, 68, 8, 30, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2554, 68, 8, 29, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2555, 68, 8, 31, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2556, 68, 8, 32, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2557, 68, 5, 20, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2558, 68, 5, 17, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2559, 68, 5, 19, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2560, 68, 5, 18, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2561, 68, 36, 181, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2562, 68, 36, 178, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2563, 68, 36, 180, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2564, 68, 36, 179, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2565, 68, 34, 171, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2566, 68, 34, 173, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2567, 68, 34, 170, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2568, 68, 34, 172, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2569, 68, 32, 164, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2570, 68, 32, 162, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2571, 68, 32, 165, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2572, 68, 32, 163, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2573, 68, 3, 9, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2574, 68, 3, 10, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2575, 68, 3, 11, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2576, 68, 3, 12, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2577, 68, 28, 149, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2578, 68, 28, 148, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2579, 68, 28, 146, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2580, 68, 28, 147, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2581, 68, 35, 175, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2582, 68, 35, 177, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2583, 68, 35, 176, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2584, 68, 35, 174, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2585, 68, 39, 193, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2586, 68, 39, 191, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2587, 68, 39, 190, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2588, 68, 39, 192, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2589, 68, 10, 38, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2590, 68, 10, 40, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2591, 68, 10, 37, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2592, 68, 10, 39, NULL, NULL, '2025-06-17 01:18:07', '2025-06-17 01:18:07'),
(2593, 69, 44, 110, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2594, 69, 44, 111, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2595, 69, 44, 113, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2596, 69, 44, 112, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2597, 69, 17, 66, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2598, 69, 17, 67, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2599, 69, 17, 68, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2600, 69, 17, 65, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2601, 69, 47, 122, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2602, 69, 47, 123, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2603, 69, 47, 125, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2604, 69, 47, 124, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2605, 69, 18, 70, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2606, 69, 18, 72, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2607, 69, 18, 71, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2608, 69, 18, 69, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2609, 69, 2, 8, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2610, 69, 2, 5, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2611, 69, 2, 7, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2612, 69, 2, 6, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2613, 69, 22, 86, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2614, 69, 22, 88, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2615, 69, 22, 87, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2616, 69, 22, 85, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2617, 69, 50, 137, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2618, 69, 50, 134, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2619, 69, 50, 135, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2620, 69, 50, 136, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2621, 69, 24, 96, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2622, 69, 24, 93, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2623, 69, 24, 94, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2624, 69, 24, 95, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2625, 69, 48, 128, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2626, 69, 48, 129, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2627, 69, 48, 126, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2628, 69, 48, 127, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2629, 69, 51, 141, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2630, 69, 51, 140, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2631, 69, 51, 139, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2632, 69, 51, 138, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2633, 69, 27, 105, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2634, 69, 27, 108, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2635, 69, 27, 107, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2636, 69, 27, 106, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2637, 69, 52, 142, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2638, 69, 52, 143, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2639, 69, 52, 145, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2640, 69, 52, 144, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2641, 69, 11, 41, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2642, 69, 11, 43, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2643, 69, 11, 44, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2644, 69, 11, 42, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2645, 69, 14, 56, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2646, 69, 14, 54, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2647, 69, 14, 53, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2648, 69, 14, 55, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2649, 69, 15, 57, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2650, 69, 15, 59, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2651, 69, 15, 58, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2652, 69, 15, 60, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2653, 69, 5, 17, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2654, 69, 5, 19, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2655, 69, 5, 18, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2656, 69, 5, 20, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2657, 69, 3, 11, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2658, 69, 3, 10, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2659, 69, 3, 9, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2660, 69, 3, 12, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2661, 69, 32, 164, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2662, 69, 32, 163, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2663, 69, 32, 165, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2664, 69, 32, 162, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2665, 69, 10, 39, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2666, 69, 10, 38, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2667, 69, 10, 37, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2668, 69, 10, 40, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2669, 69, 28, 149, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2670, 69, 28, 147, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2671, 69, 28, 146, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2672, 69, 28, 148, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2673, 69, 30, 156, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2674, 69, 30, 154, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2675, 69, 30, 157, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2676, 69, 30, 155, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2677, 69, 9, 34, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2678, 69, 9, 35, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2679, 69, 9, 36, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2680, 69, 9, 33, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2681, 69, 31, 158, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2682, 69, 31, 160, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2683, 69, 31, 159, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2684, 69, 31, 161, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2685, 69, 29, 150, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2686, 69, 29, 152, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2687, 69, 29, 153, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2688, 69, 29, 151, NULL, NULL, '2025-06-17 10:49:35', '2025-06-17 10:49:35'),
(2689, 70, 49, 132, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2690, 70, 49, 133, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2691, 70, 49, 131, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2692, 70, 49, 130, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2693, 70, 19, 76, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2694, 70, 19, 73, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2695, 70, 19, 75, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2696, 70, 19, 74, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2697, 70, 44, 112, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2698, 70, 44, 113, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2699, 70, 44, 110, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2700, 70, 44, 111, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2701, 70, 20, 78, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2702, 70, 20, 79, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2703, 70, 20, 77, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2704, 70, 20, 80, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2705, 70, 26, 103, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2706, 70, 26, 101, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2707, 70, 26, 102, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2708, 70, 26, 104, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2709, 70, 51, 139, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2710, 70, 51, 140, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2711, 70, 51, 138, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2712, 70, 51, 141, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2713, 70, 46, 120, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2714, 70, 46, 119, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2715, 70, 46, 121, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2716, 70, 46, 118, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2717, 70, 23, 90, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2718, 70, 23, 92, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2719, 70, 23, 89, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2720, 70, 23, 91, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2721, 70, 24, 94, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2722, 70, 24, 96, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2723, 70, 24, 93, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2724, 70, 24, 95, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2725, 70, 17, 66, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2726, 70, 17, 67, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2727, 70, 17, 68, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2728, 70, 17, 65, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2729, 70, 21, 81, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2730, 70, 21, 84, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2731, 70, 21, 82, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2732, 70, 21, 83, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2733, 70, 18, 69, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2734, 70, 18, 70, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2735, 70, 18, 71, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2736, 70, 18, 72, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2737, 70, 39, 191, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2738, 70, 39, 192, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2739, 70, 39, 190, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2740, 70, 39, 193, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2741, 70, 30, 156, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2742, 70, 30, 154, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2743, 70, 30, 155, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2744, 70, 30, 157, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2745, 70, 6, 23, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2746, 70, 6, 21, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2747, 70, 6, 24, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2748, 70, 6, 22, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2749, 70, 38, 189, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2750, 70, 38, 187, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2751, 70, 38, 186, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2752, 70, 38, 188, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2753, 70, 31, 160, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2754, 70, 31, 158, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2755, 70, 31, 159, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2756, 70, 31, 161, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2757, 70, 8, 29, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2758, 70, 8, 30, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2759, 70, 8, 32, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2760, 70, 8, 31, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2761, 70, 12, 47, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2762, 70, 12, 46, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2763, 70, 12, 45, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2764, 70, 12, 48, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2765, 70, 34, 173, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2766, 70, 34, 170, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2767, 70, 34, 171, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2768, 70, 34, 172, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2769, 70, 36, 178, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2770, 70, 36, 180, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2771, 70, 36, 181, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2772, 70, 36, 179, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2773, 70, 14, 54, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2774, 70, 14, 55, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2775, 70, 14, 53, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2776, 70, 14, 56, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2777, 70, 4, 14, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2778, 70, 4, 16, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2779, 70, 4, 15, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2780, 70, 4, 13, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2781, 70, 13, 51, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2782, 70, 13, 52, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2783, 70, 13, 49, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2784, 70, 13, 50, NULL, NULL, '2025-06-21 00:44:53', '2025-06-21 00:44:53'),
(2785, 71, 18, 71, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2786, 71, 18, 69, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2787, 71, 18, 70, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2788, 71, 18, 72, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2789, 71, 17, 68, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2790, 71, 17, 67, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2791, 71, 17, 65, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2792, 71, 17, 66, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2793, 71, 24, 95, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2794, 71, 24, 93, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2795, 71, 24, 96, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2796, 71, 24, 94, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2797, 71, 47, 125, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2798, 71, 47, 124, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2799, 71, 47, 123, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2800, 71, 47, 122, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2801, 71, 46, 120, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2802, 71, 46, 121, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2803, 71, 46, 118, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2804, 71, 46, 119, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2805, 71, 45, 116, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2806, 71, 45, 114, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2807, 71, 45, 115, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2808, 71, 45, 117, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2809, 71, 27, 106, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2810, 71, 27, 105, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2811, 71, 27, 108, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2812, 71, 27, 107, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2813, 71, 21, 81, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2814, 71, 21, 83, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2815, 71, 21, 82, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2816, 71, 21, 84, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2817, 71, 1, 3, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2818, 71, 1, 2, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2819, 71, 1, 4, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2820, 71, 1, 1, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2821, 71, 26, 104, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2822, 71, 26, 101, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2823, 71, 26, 102, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2824, 71, 26, 103, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2825, 71, 48, 126, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2826, 71, 48, 129, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2827, 71, 48, 128, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2828, 71, 48, 127, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2829, 71, 16, 62, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2830, 71, 16, 64, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2831, 71, 16, 63, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2832, 71, 16, 61, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2833, 71, 31, 160, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2834, 71, 31, 159, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2835, 71, 31, 161, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2836, 71, 31, 158, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2837, 71, 15, 60, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2838, 71, 15, 57, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2839, 71, 15, 59, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2840, 71, 15, 58, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2841, 71, 9, 35, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2842, 71, 9, 36, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2843, 71, 9, 34, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2844, 71, 9, 33, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2845, 71, 11, 44, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2846, 71, 11, 41, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2847, 71, 11, 42, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2848, 71, 11, 43, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2849, 71, 3, 11, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2850, 71, 3, 12, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2851, 71, 3, 9, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2852, 71, 3, 10, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2853, 71, 13, 52, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2854, 71, 13, 49, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2855, 71, 13, 50, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2856, 71, 13, 51, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2857, 71, 10, 38, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2858, 71, 10, 40, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2859, 71, 10, 39, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2860, 71, 10, 37, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2861, 71, 5, 18, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2862, 71, 5, 17, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2863, 71, 5, 19, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2864, 71, 5, 20, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2865, 71, 37, 185, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2866, 71, 37, 182, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2867, 71, 37, 183, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2868, 71, 37, 184, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2869, 71, 35, 177, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2870, 71, 35, 174, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2871, 71, 35, 176, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2872, 71, 35, 175, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2873, 71, 34, 171, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2874, 71, 34, 172, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2875, 71, 34, 173, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2876, 71, 34, 170, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2877, 71, 7, 26, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2878, 71, 7, 28, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2879, 71, 7, 27, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44'),
(2880, 71, 7, 25, NULL, NULL, '2025-06-21 12:53:44', '2025-06-21 12:53:44');

-- --------------------------------------------------------

--
-- Table structure for table `toeic_sections`
--

CREATE TABLE `toeic_sections` (
  `section_pk` int(11) NOT NULL,
  `type_` enum('LISTENING','READING') NOT NULL,
  `section_desc` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `toeic_sections`
--

INSERT INTO `toeic_sections` (`section_pk`, `type_`, `section_desc`) VALUES
(1, 'READING', 'Incomplete sentences'),
(2, 'READING', 'Error recognition'),
(3, 'READING', 'Reading comprehension'),
(4, 'READING', 'Double passages'),
(5, 'LISTENING', 'Photos'),
(6, 'LISTENING', 'Question – Response'),
(7, 'LISTENING', 'Short conversation'),
(8, 'LISTENING', 'Short talks');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `pk_user` int(11) NOT NULL,
  `user_email` varchar(100) NOT NULL,
  `user_password` varchar(100) NOT NULL,
  `user_name` varchar(100) NOT NULL,
  `user_lastname` varchar(100) NOT NULL,
  `user_carnet` varchar(10) DEFAULT NULL,
  `user_role` varchar(20) DEFAULT NULL,
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `status` varchar(10) DEFAULT NULL,
  `verification_code` varchar(25) DEFAULT NULL,
  `is_verified` tinyint(1) DEFAULT NULL,
  `last_code_sent_at` datetime DEFAULT NULL,
  `test_attempts` int(11) DEFAULT 0,
  `last_test_attempt_at` date DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`pk_user`, `user_email`, `user_password`, `user_name`, `user_lastname`, `user_carnet`, `user_role`, `created_at`, `updated_at`, `status`, `verification_code`, `is_verified`, `last_code_sent_at`, `test_attempts`, `last_test_attempt_at`) VALUES
(1, 'diego.alas20@itca.edu.sv', '$2b$12$c8UxdsABjP3wM4aBcMkFueZIhmEcZsOHIZiYiE/dhbVK2UncoPIha', 'Diego Alexander', 'Alas Morales', '024120', 'admin', '2025-04-17 14:41:40', '2025-05-28 23:52:04', 'ACTIVE', '223813', 1, '2025-05-28 23:51:26', 0, NULL),
(2, 'ivan.osorio20@itca.edu.sv', '$2b$12$I3HZ4ZZNpdUqo7PByHl.ae/LXwCDRbwQ2lMS8yfIsaqzLd9eJtDb6', 'Ivan', 'Osorio', '020320', 'student', '2025-04-17 14:42:48', '2025-05-28 23:52:12', 'ACTIVE', NULL, 1, NULL, 0, NULL),
(3, 'pedro@itca.edu.sv', '$2b$12$DC0q29icM2M5X7yJsW6Gj.Ley8qgXHfFyxbfvp.ItJO65pTXE.kMi', 'Pedro', 'Dias', '123456', 'admin', '2025-04-17 14:45:32', '2025-05-28 23:52:17', 'ACTIVE', NULL, 1, NULL, 0, NULL),
(6, 'roberto@itca.edu.sv', '$2b$12$eVRVCKS2FA8Ue7Yl.y02p.Mfnrt/cUhlgrp9R.UhXsN5RfXXmsm22', 'Roberto', 'Perez', '0000001', 'student', '2025-04-17 14:46:06', '2025-05-28 23:52:21', 'INACTIVE', NULL, 1, NULL, 0, NULL),
(10, 'marcos.morales@itca.edu.sv', '$2b$12$t3yCsokeRSihqI5YbY1Hxe9I/XS.k42pmrXr1uKctEmCE56PeZVmO', 'Marcos', 'Morales', '578855', 'student', '2025-05-08 20:52:41', '2025-05-28 23:52:25', 'INACTIVE', NULL, 1, NULL, 0, NULL),
(11, 'douglas.martinez@itca.edu.sv', '$2b$12$fI0c.zTk3w6f8962yVAisus4Ewes/h503BC/nctrQ8ZYyZEec47xe', 'Douglas', 'Martinez', '343544', 'student', '2025-05-08 20:54:23', '2025-05-28 23:52:33', 'ACTIVE', NULL, 1, NULL, 0, NULL),
(12, 'diegoalas06+1@gmail.com', '$2b$12$FAU8YLk1MEzKguzhj7aLEeQRhDZ7Xmqk0r8mDsRrhXyYk5hlecHJ.', 'Diego', 'Alas', '77777777', 'teacher', '2025-05-21 15:42:02', '2025-05-28 23:52:37', 'ACTIVE', NULL, 1, NULL, 0, NULL),
(13, 'diegoalas06+2@gmail.com', '$2b$12$7xvmoVH2Kntfj17HMBJ2ceUnFU72IYB.zFSBJy.gJCuiOKNGF.5sO', 'Diego', 'Student Test', '22222222', 'student', '2025-05-21 16:34:37', '2025-05-29 13:31:23', 'ACTIVE', NULL, 1, NULL, 0, NULL),
(16, 'diegoalas06+3@gmail.com', '$2b$12$GAU361mOqm1QqCBEc1Ow7.ngeSEZfQWgOcH9Kygb5SU65xnDBDRWO', 'Diego', 'Test1', '11223344', 'student', '2025-05-28 16:18:51', '2025-05-29 14:08:06', 'ACTIVE', NULL, 1, '2025-05-29 14:00:22', 0, NULL),
(18, 'diegoalas06+4@gmail.com', '$2b$12$NWQCoWTU3uiwIY6aiN097eSh7yX9Ssr91da0Ogao4iav98VKYctm2', 'Diego', 'Test2', '22334455', 'student', '2025-05-28 16:20:13', '2025-05-29 00:06:15', 'ACTIVE', NULL, 1, '2025-05-29 00:05:41', 0, NULL),
(19, 'diegoalas06+5@gmail.com', '$2b$12$XUrHm3RIVzuWMX4TDQ8nl.0DZGRfxtXaj4DPwz5rWoKt7SJU1uI1a', 'Diego', 'Test2', '2233445555', 'student', '2025-05-28 16:25:56', '2025-05-28 16:29:01', 'ACTIVE', NULL, 1, NULL, 0, NULL),
(20, 'diegoalas06+6@gmail.com', '$2b$12$AtywakD1/AzN9ZPOMP6LzOu.VE5ewAMP/bjC6adW57R86NsXv5bM6', 'Usuario', 'Test', '33445566', 'student', '2025-05-28 17:07:13', '2025-05-28 17:08:23', 'ACTIVE', NULL, 1, NULL, 0, NULL),
(21, 'diegoalas06+9@gmail.com', '$2b$12$qIsDHZIiK2eXGa1QB5Sc1.KfEoSmDJ5kNAP0zRN.RbADz4/NCJ12W', 'Test', 'Tes4', '999999999', 'student', '2025-05-28 18:18:25', '2025-05-28 18:19:08', 'ACTIVE', NULL, 1, NULL, 0, NULL),
(22, 'diegoalas06+10@gmail.com', '$2b$12$vM.B8CbA2OegkW2HOkBebO23IETP4rAaxIbcRHoxCyZ49gPOE3c/.', 'Diego Test', 'Alas Test', '88995511', 'student', '2025-05-28 23:38:10', '2025-05-29 00:19:33', 'ACTIVE', NULL, 1, '2025-05-29 00:17:48', 0, NULL),
(24, 'diegoalas06+11@gmail.com', '$2b$12$SDMwZdfbO6x3E9aUvsLSeOXvXVkWzKDfuWZRLQC6X6tVoOrtIQWEG', 'Diego Test', 'Alas Test', '88995512', 'student', '2025-05-28 23:42:54', '2025-05-29 00:33:05', 'ACTIVE', NULL, 1, '2025-05-29 00:24:57', 0, NULL),
(25, 'diegoalas06+12@gmail.com', '$2b$12$O5Ki5kFaOQuujMtiZbUZquFgUrKBAJZ9rcvkP8j/A.CzHDqawlOw.', 'Diego Test', 'Alas Test', '88995513', 'student', '2025-05-28 23:44:05', '2025-05-28 23:44:05', 'PENDING', '605492', 0, NULL, 0, NULL),
(26, 'diegoalas06@gmail.com', '$2b$12$NdBFpQDVbuF7VNF8iIJRFuli/KChCh9yx/LXMtNv8cPOAoKkvhPGe', 'Diego', 'Alas', NULL, 'student', '2025-06-07 13:57:17', '2025-06-07 13:58:28', 'ACTIVE', NULL, 1, NULL, 0, NULL),
(27, 'diegoalas06+22@gmail.com', '$2b$12$/u0qUChHJS5RneX56urV9O3X/ZBskOr.kDbfPA2X8Sc6g/Y5uHkHe', 'Diego', 'Alas', NULL, 'student', '2025-06-07 14:02:16', '2025-06-07 14:02:16', 'ACTIVE', NULL, 1, NULL, 0, NULL),
(28, 'diegoalas06+23@gmail.com', '$2b$12$Rns2jPLw4ccDZR.uq/0LKuPBTJLG6cXj34/s3N0et/8nsvWtWuxNm', 'Diego', 'Alas', NULL, 'student', '2025-06-07 14:03:12', '2025-06-07 14:05:16', 'ACTIVE', NULL, 1, NULL, 0, NULL),
(29, 'diegoalas06+24@gmail.com', '$2b$12$ucj.iG3vQ9d8YFa5QsCPHOZrAqk71rwfjB8OVNDXqb6nt7ngSN4Wq', 'Diego', 'Alas', NULL, 'student', '2025-06-07 14:13:23', '2025-06-07 14:16:46', 'ACTIVE', NULL, 1, NULL, 0, NULL),
(30, 'diegoalas06+25@gmail.com', '$2b$12$y2OeiysnzQT2X3rHc9Fwx.i6TpxF4o7UEpwccPUYS6psqMeuKkUQO', 'Diego', 'Alas', NULL, 'student', '2025-06-07 14:19:22', '2025-06-07 14:19:47', 'ACTIVE', NULL, 1, NULL, 0, NULL),
(34, 'diegoalas06+26@gmail.com', '$2b$12$miv6m2AHbJz8Y332A1f4j.elA3dPpbGVacQGHgnxbd0VaUB.V4Fea', 'Diego', 'Alas', NULL, 'student', '2025-06-17 11:37:05', '2025-06-17 11:53:51', 'ACTIVE', NULL, 1, '2025-06-17 11:43:20', 0, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `weaknesses`
--

CREATE TABLE `weaknesses` (
  `pk_weakness` int(11) NOT NULL,
  `test_fk` int(11) NOT NULL,
  `weakness_text` text NOT NULL,
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `weaknesses`
--

INSERT INTO `weaknesses` (`pk_weakness`, `test_fk`, `weakness_text`, `created_at`, `updated_at`) VALUES
(6, 29, 'The student missed a straightforward question about the application deadline in the reading section, which was an A2 level question, suggesting a need for more attention to detail. Additionally, they incorrectly answered a B1 level question in the listening section about what the interviewer asked, indicating potential difficulties with understanding specific questions or nuances in spoken English.', '2025-05-05 15:20:16', '2025-05-05 15:20:16'),
(7, 29, 'The student struggles with accurately recalling specific details, such as the application deadline in the reading section, which was an A2 level question. Additionally, in the listening section, they misinterpreted the interviewer\'s question about the candidate\'s future aspirations as being about previous work experience, indicating a need for improved listening comprehension skills, especially in distinguishing between similar topics.', '2025-05-05 15:22:34', '2025-05-05 15:22:34'),
(8, 29, 'The student missed a straightforward question about the application deadline in the reading section, which was an A2 level question, suggesting a need for more attention to detail. Additionally, they incorrectly answered a B1 level question in the listening section about what the interviewer asked, indicating potential difficulties with understanding specific questions or nuances in spoken English.', '2025-05-07 17:40:25', '2025-05-07 17:40:25'),
(9, 29, 'The student struggled with an A2 level question in the reading section about the application deadline, incorrectly answering \'June 15th\' instead of \'May 30th\'. This indicates a need for closer attention to detail in reading comprehension. Additionally, they missed a B1 level question in the listening section about what the interviewer asked, suggesting some difficulty in fully grasping the context or details in spoken English.', '2025-05-07 17:43:45', '2025-05-07 17:43:45'),
(10, 29, 'The student missed a straightforward question about the application deadline in the reading section, which was an A2 level question, suggesting a need for more attention to detail. Additionally, they incorrectly answered a B1 level question in the listening section about what the interviewer asked, indicating potential difficulties with understanding specific questions or nuances in spoken English.', '2025-05-09 11:06:35', '2025-05-09 11:06:35'),
(11, 29, 'The student struggled with identifying the application deadline in the reading section, indicating a need for improvement in attention to detail and specific information retrieval. Additionally, the incorrect answer regarding what the interviewer asked about in the listening section suggests difficulties in interpreting questions or main ideas from spoken dialogues, especially at the B1 level.', '2025-05-21 12:40:22', '2025-05-21 12:40:22'),
(12, 29, 'The response \'hola\' is not relevant to any TOEIC exam sections or questions, indicating a significant lack of understanding or preparation for the exam format and requirements.', '2025-05-21 12:56:05', '2025-05-21 12:56:05'),
(13, 29, 'The student struggled with accurately identifying specific details, such as the application deadline in the reading section and the main topic of the interviewer\'s question in the listening section. This suggests a need for improvement in attention to detail and possibly in vocabulary related to time and work experience.', '2025-05-21 12:58:42', '2025-05-21 12:58:42'),
(14, 29, 'The student struggles with accurately identifying application deadlines in the \'Reading comprehension\' section, as evidenced by the incorrect answer regarding the deadline. Additionally, in the \'Listening comprehension\' section, there was a misunderstanding of the interviewer\'s question about previous work experience, indicating a need for improved listening skills for detail and context.', '2025-05-21 12:59:57', '2025-05-21 12:59:57'),
(15, 29, 'The student struggles with accurately recalling specific details, such as the application deadline in the reading section, indicating a need for improved attention to detail. Additionally, the incorrect answer regarding what the interviewer asks about in the listening section suggests a difficulty in fully understanding the context or nuances of spoken English, especially in more complex questions.', '2025-05-26 08:50:26', '2025-05-26 08:50:26'),
(16, 41, 'The student struggles with reading comprehension questions, especially those at the A1 and A2 levels, indicating difficulty with basic understanding and inference from texts. There are also instances of unanswered questions and incorrect answers in listening comprehension, suggesting challenges in processing spoken English and extracting key information from conversations.', '2025-05-26 11:27:10', '2025-05-26 11:27:10'),
(17, 41, 'The student struggles with basic comprehension in some A1 level questions, particularly in the \'Reading comprehension\' and \'Short conversation\' sections. For instance, incorrectly answering \'What should you use in case of fire?\' with \'Elevators\' instead of \'stairs\', and misunderstanding simple instructions or details in conversations. There are also instances where the student did not answer questions, indicating possible difficulties with time management or understanding the questions.', '2025-05-26 11:27:32', '2025-05-26 11:27:32'),
(18, 29, 'The student struggled with accurately identifying the application deadline, confusing \'May 30th\' with \'June 15th\'. Additionally, they misinterpreted the interviewer\'s question about the candidate\'s future, indicating a need for improved attention to detail and comprehension in both reading and listening contexts.', '2025-05-26 11:33:17', '2025-05-26 11:33:17'),
(19, 54, 'The student failed to answer the majority of the questions, including very basic ones at the A1 level, indicating significant gaps in both vocabulary and comprehension skills across all tested areas. The student also did not attempt many questions, which suggests difficulties with time management or confidence in their English abilities.', '2025-05-27 22:24:17', '2025-05-27 22:24:17'),
(20, 63, 'The student struggled with answering questions correctly across both reading and listening sections, especially those requiring comprehension of slightly more complex information or context. Many questions were left unanswered, indicating difficulty with time management or understanding the material. Specific areas of difficulty include understanding detailed instructions, identifying main purposes of texts, and comprehending conversations that include indirect information or require inference.', '2025-06-07 13:14:34', '2025-06-07 13:14:34'),
(21, 64, 'The student failed to answer the majority of the reading comprehension questions, indicating a significant weakness in understanding written English texts across various contexts.', '2025-06-16 23:25:40', '2025-06-16 23:25:40'),
(22, 64, 'There were multiple instances where the student did not attempt to answer questions (\'No respondida\'), suggesting difficulties with time management or confidence in tackling reading sections.', '2025-06-16 23:25:40', '2025-06-16 23:25:40'),
(23, 64, 'The student struggled with grammar and vocabulary in the incomplete sentences section, as seen in incorrect answers like \'delivering\' for a context requiring \'delivered\' and misunderstanding the use of \'since\' versus \'for\' in time expressions.', '2025-06-16 23:25:40', '2025-06-16 23:25:40'),
(24, 65, 'The student failed to answer the majority of the questions, indicating a significant lack of comprehension in both reading and listening sections.', '2025-06-16 23:39:37', '2025-06-16 23:39:37'),
(25, 65, 'In the reading section, the student did not provide answers to questions about application deadlines, types of internships, and other straightforward information, suggesting difficulties with basic reading comprehension.', '2025-06-16 23:39:37', '2025-06-16 23:39:37'),
(26, 65, 'In the listening section, the student did not answer any questions correctly, showing a lack of understanding of spoken English in various contexts, such as conversations about reservations, directions, and health issues.', '2025-06-16 23:39:37', '2025-06-16 23:39:37'),
(27, 67, 'El estudiante mostró dificultades significativas en la comprensión lectora, no respondiendo a la mayoría de las preguntas o respondiendo incorrectamente. Esto sugiere una falta de comprensión básica del inglés escrito.', '2025-06-17 00:24:11', '2025-06-17 00:24:11'),
(28, 67, 'En las secciones de conversación corta, el estudiante no respondió a ninguna pregunta, lo que indica una falta de comprensión auditiva o incapacidad para procesar información hablada en inglés.', '2025-06-17 00:24:11', '2025-06-17 00:24:11'),
(29, 67, 'La incapacidad para responder preguntas básicas sobre textos simples y conversaciones sugiere que el estudiante tiene un vocabulario muy limitado y poca comprensión de la gramática inglesa.', '2025-06-17 00:24:11', '2025-06-17 00:24:11'),
(30, 68, 'El estudiante no respondió a ninguna de las preguntas, lo que indica una falta de comprensión o preparación para el examen TOEIC.', '2025-06-17 01:18:35', '2025-06-17 01:18:35'),
(31, 68, 'No se observa capacidad para comprender textos simples o conversaciones básicas en inglés.', '2025-06-17 01:18:35', '2025-06-17 01:18:35'),
(32, 68, 'Falta de habilidad para identificar información específica en textos o diálogos, incluso en contextos muy sencillos.', '2025-06-17 01:18:35', '2025-06-17 01:18:35');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `answers`
--
ALTER TABLE `answers`
  ADD PRIMARY KEY (`pk_answer`),
  ADD KEY `idx_question_fk` (`question_fk`);

--
-- Indexes for table `api_usage_log`
--
ALTER TABLE `api_usage_log`
  ADD PRIMARY KEY (`pk_log`),
  ADD UNIQUE KEY `unique_user_endpoint_date` (`fk_user`,`endpoint`,`request_date`);

--
-- Indexes for table `level_history`
--
ALTER TABLE `level_history`
  ADD PRIMARY KEY (`pk_history`),
  ADD KEY `idx_level_fk` (`level_fk`),
  ADD KEY `idx_user_fk` (`user_fk`);

--
-- Indexes for table `login_attempts_ip`
--
ALTER TABLE `login_attempts_ip`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `ip_address` (`ip_address`);

--
-- Indexes for table `mcer_level`
--
ALTER TABLE `mcer_level`
  ADD PRIMARY KEY (`pk_level`);

--
-- Indexes for table `password_reset_tokens`
--
ALTER TABLE `password_reset_tokens`
  ADD PRIMARY KEY (`id`),
  ADD KEY `user_id` (`user_id`);

--
-- Indexes for table `prompts`
--
ALTER TABLE `prompts`
  ADD PRIMARY KEY (`pk_prompt`),
  ADD KEY `idx_prompt_name` (`prompt_name`);

--
-- Indexes for table `questions`
--
ALTER TABLE `questions`
  ADD PRIMARY KEY (`pk_question`),
  ADD KEY `idx_level_fk` (`level_fk`),
  ADD KEY `idx_title_fk` (`title_fk`),
  ADD KEY `toeic_section_fk` (`toeic_section_fk`);

--
-- Indexes for table `questions_titles`
--
ALTER TABLE `questions_titles`
  ADD PRIMARY KEY (`pk_title`);

--
-- Indexes for table `recommendations`
--
ALTER TABLE `recommendations`
  ADD PRIMARY KEY (`pk_recommend`),
  ADD KEY `idx_test_fk` (`test_fk`);

--
-- Indexes for table `strengths`
--
ALTER TABLE `strengths`
  ADD PRIMARY KEY (`pk_strength`),
  ADD KEY `idx_test_fk` (`test_fk`);

--
-- Indexes for table `study_materials`
--
ALTER TABLE `study_materials`
  ADD PRIMARY KEY (`pk_studymaterial`),
  ADD KEY `idx_level_fk` (`level_fk`),
  ADD KEY `idx_title` (`studymaterial_title`),
  ADD KEY `idx_tags` (`studymaterial_tags`);

--
-- Indexes for table `tests`
--
ALTER TABLE `tests`
  ADD PRIMARY KEY (`pk_test`),
  ADD KEY `idx_user_fk` (`user_fk`),
  ADD KEY `idx_level_fk` (`level_fk`);

--
-- Indexes for table `test_comments`
--
ALTER TABLE `test_comments`
  ADD PRIMARY KEY (`pk_comment`),
  ADD KEY `idx_user_fk` (`user_fk`),
  ADD KEY `idx_test_fk` (`test_fk`);

--
-- Indexes for table `test_details`
--
ALTER TABLE `test_details`
  ADD PRIMARY KEY (`pk_testdetail`),
  ADD KEY `idx_test_fk` (`test_fk`),
  ADD KEY `idx_question_fk` (`question_fk`),
  ADD KEY `idx_answer_fk` (`answer_fk`);

--
-- Indexes for table `toeic_sections`
--
ALTER TABLE `toeic_sections`
  ADD PRIMARY KEY (`section_pk`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`pk_user`),
  ADD UNIQUE KEY `user_email` (`user_email`),
  ADD KEY `idx_email` (`user_email`);

--
-- Indexes for table `weaknesses`
--
ALTER TABLE `weaknesses`
  ADD PRIMARY KEY (`pk_weakness`),
  ADD KEY `idx_test_fk` (`test_fk`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `answers`
--
ALTER TABLE `answers`
  MODIFY `pk_answer` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=805;

--
-- AUTO_INCREMENT for table `api_usage_log`
--
ALTER TABLE `api_usage_log`
  MODIFY `pk_log` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `level_history`
--
ALTER TABLE `level_history`
  MODIFY `pk_history` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=25;

--
-- AUTO_INCREMENT for table `login_attempts_ip`
--
ALTER TABLE `login_attempts_ip`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=12;

--
-- AUTO_INCREMENT for table `mcer_level`
--
ALTER TABLE `mcer_level`
  MODIFY `pk_level` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `password_reset_tokens`
--
ALTER TABLE `password_reset_tokens`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `prompts`
--
ALTER TABLE `prompts`
  MODIFY `pk_prompt` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `questions`
--
ALTER TABLE `questions`
  MODIFY `pk_question` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=198;

--
-- AUTO_INCREMENT for table `questions_titles`
--
ALTER TABLE `questions_titles`
  MODIFY `pk_title` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=108;

--
-- AUTO_INCREMENT for table `recommendations`
--
ALTER TABLE `recommendations`
  MODIFY `pk_recommend` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=43;

--
-- AUTO_INCREMENT for table `strengths`
--
ALTER TABLE `strengths`
  MODIFY `pk_strength` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=25;

--
-- AUTO_INCREMENT for table `study_materials`
--
ALTER TABLE `study_materials`
  MODIFY `pk_studymaterial` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `tests`
--
ALTER TABLE `tests`
  MODIFY `pk_test` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=72;

--
-- AUTO_INCREMENT for table `test_comments`
--
ALTER TABLE `test_comments`
  MODIFY `pk_comment` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `test_details`
--
ALTER TABLE `test_details`
  MODIFY `pk_testdetail` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2881;

--
-- AUTO_INCREMENT for table `toeic_sections`
--
ALTER TABLE `toeic_sections`
  MODIFY `section_pk` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `pk_user` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=35;

--
-- AUTO_INCREMENT for table `weaknesses`
--
ALTER TABLE `weaknesses`
  MODIFY `pk_weakness` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=33;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `answers`
--
ALTER TABLE `answers`
  ADD CONSTRAINT `answers_ibfk_1` FOREIGN KEY (`question_fk`) REFERENCES `questions` (`pk_question`);

--
-- Constraints for table `api_usage_log`
--
ALTER TABLE `api_usage_log`
  ADD CONSTRAINT `fk_user_log` FOREIGN KEY (`fk_user`) REFERENCES `users` (`pk_user`);

--
-- Constraints for table `level_history`
--
ALTER TABLE `level_history`
  ADD CONSTRAINT `level_history_ibfk_1` FOREIGN KEY (`level_fk`) REFERENCES `mcer_level` (`pk_level`),
  ADD CONSTRAINT `level_history_ibfk_2` FOREIGN KEY (`user_fk`) REFERENCES `users` (`pk_user`);

--
-- Constraints for table `password_reset_tokens`
--
ALTER TABLE `password_reset_tokens`
  ADD CONSTRAINT `password_reset_tokens_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`pk_user`);

--
-- Constraints for table `questions`
--
ALTER TABLE `questions`
  ADD CONSTRAINT `questions_ibfk_1` FOREIGN KEY (`level_fk`) REFERENCES `mcer_level` (`pk_level`),
  ADD CONSTRAINT `questions_ibfk_2` FOREIGN KEY (`title_fk`) REFERENCES `questions_titles` (`pk_title`),
  ADD CONSTRAINT `toeic_section_fk` FOREIGN KEY (`toeic_section_fk`) REFERENCES `toeic_sections` (`section_pk`);

--
-- Constraints for table `recommendations`
--
ALTER TABLE `recommendations`
  ADD CONSTRAINT `recommendations_ibfk_1` FOREIGN KEY (`test_fk`) REFERENCES `tests` (`pk_test`);

--
-- Constraints for table `strengths`
--
ALTER TABLE `strengths`
  ADD CONSTRAINT `strengths_ibfk_1` FOREIGN KEY (`test_fk`) REFERENCES `tests` (`pk_test`);

--
-- Constraints for table `study_materials`
--
ALTER TABLE `study_materials`
  ADD CONSTRAINT `study_materials_ibfk_1` FOREIGN KEY (`level_fk`) REFERENCES `mcer_level` (`pk_level`);

--
-- Constraints for table `tests`
--
ALTER TABLE `tests`
  ADD CONSTRAINT `tests_ibfk_1` FOREIGN KEY (`user_fk`) REFERENCES `users` (`pk_user`),
  ADD CONSTRAINT `tests_ibfk_2` FOREIGN KEY (`level_fk`) REFERENCES `mcer_level` (`pk_level`);

--
-- Constraints for table `test_comments`
--
ALTER TABLE `test_comments`
  ADD CONSTRAINT `test_comments_ibfk_1` FOREIGN KEY (`user_fk`) REFERENCES `users` (`pk_user`),
  ADD CONSTRAINT `test_comments_ibfk_2` FOREIGN KEY (`test_fk`) REFERENCES `tests` (`pk_test`);

--
-- Constraints for table `test_details`
--
ALTER TABLE `test_details`
  ADD CONSTRAINT `test_details_ibfk_1` FOREIGN KEY (`test_fk`) REFERENCES `tests` (`pk_test`),
  ADD CONSTRAINT `test_details_ibfk_2` FOREIGN KEY (`question_fk`) REFERENCES `questions` (`pk_question`),
  ADD CONSTRAINT `test_details_ibfk_3` FOREIGN KEY (`answer_fk`) REFERENCES `answers` (`pk_answer`);

--
-- Constraints for table `weaknesses`
--
ALTER TABLE `weaknesses`
  ADD CONSTRAINT `weaknesses_ibfk_1` FOREIGN KEY (`test_fk`) REFERENCES `tests` (`pk_test`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
