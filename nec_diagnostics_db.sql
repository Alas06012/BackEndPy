create database nec_diagnostics_db
use nec_diagnostics_db

-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Apr 20, 2025 at 12:12 AM
-- Server version: 10.4.28-MariaDB
-- PHP Version: 8.2.4

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
(16, 4, 'Anne has completed it.', 0, 'ACTIVE', '2025-04-19 15:42:28', '2025-04-19 15:42:28');

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
-- Table structure for table `prompts`
--

CREATE TABLE `prompts` (
  `pk_prompt` int(11) NOT NULL,
  `prompt_name` varchar(50) NOT NULL,
  `prompt_value` varchar(750) NOT NULL,
  `created_at` datetime DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

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
(1, 3, 'What is the main objective of the message?', 1, 4, 'ACTIVE', '2025-04-19 15:22:28', '2025-04-19 15:47:26'),
(2, 3, 'What can be implied about the workshop', 1, 4, 'ACTIVE', '2025-04-19 15:34:27', '2025-04-19 15:47:26'),
(3, 3, 'What can be implied about Dr Friedman?', 1, 4, 'ACTIVE', '2025-04-19 15:37:34', '2025-04-19 15:47:26'),
(4, 3, 'What has happened to the address list?', 1, 4, 'ACTIVE', '2025-04-19 15:42:28', '2025-04-19 15:47:26');

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
(1, 'Dear Helen - Workshop Feedback', 'Dear Helen,\n\nI would like to congratulate you on organising such an excellent and informative workshop. I know a lot of people learnt a great deal from it. Can you pass on my thanks to Doctor Friedman for his fascinating talk on Staff Motivation? I realise how lucky we were that he was able to find the time for us. The feedback from the staff was very positive. Let’s hope we actually see an improvement in staff motivation as a result!\n\nBy the way, I’m missing my list of addresses of the delegates who attended. Did I happen to leave it in your office? It’s just that I haven’t seen it since our meeting on Friday.\n\nThanks again for a great day,\nAnne', 'READING', NULL, 'ACTIVE', '2025-04-19 12:47:13', '2025-04-19 15:47:26'),
(2, 'Incomplete Sentences', 'For each question you will see an incomplete sentence. You are to choose the one word or phrase that best completes the sentence', 'READING', NULL, 'ACTIVE', '2025-04-19 14:46:19', '2025-04-19 14:46:19');

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

-- --------------------------------------------------------

--
-- Table structure for table `tests`
--

CREATE TABLE `tests` (
  `pk_test` int(11) NOT NULL,
  `user_fk` int(11) NOT NULL,
  `test_points` int(10) DEFAULT NULL,
  `test_passed` int(1) DEFAULT NULL,
  `level_fk` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

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
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

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
  `user_carnet` varchar(10) NOT NULL,
  `user_role` varchar(20) DEFAULT NULL,
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `status` varchar(10) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`pk_user`, `user_email`, `user_password`, `user_name`, `user_lastname`, `user_carnet`, `user_role`, `created_at`, `updated_at`, `status`) VALUES
(1, 'diego.alas20@itca.edu.sv', '$2b$12$c8UxdsABjP3wM4aBcMkFueZIhmEcZsOHIZiYiE/dhbVK2UncoPIha', 'Diego Alexander', 'Alas Morales', '024120', 'admin', '2025-04-17 14:41:40', '2025-04-19 11:03:40', 'ACTIVE'),
(2, 'ivan.osorio20@itca.edu.sv', '$2b$12$I3HZ4ZZNpdUqo7PByHl.ae/LXwCDRbwQ2lMS8yfIsaqzLd9eJtDb6', 'Ivan', 'Osorio', '020320', 'student', '2025-04-17 14:42:48', '2025-04-17 14:42:48', 'ACTIVE'),
(3, 'pedro@itca.edu.sv', '$2b$12$DC0q29icM2M5X7yJsW6Gj.Ley8qgXHfFyxbfvp.ItJO65pTXE.kMi', 'Pedro', 'Dias', '0000000', 'student', '2025-04-17 14:45:32', '2025-04-17 14:45:32', 'ACTIVE'),
(6, 'roberto@itca.edu.sv', '$2b$12$eVRVCKS2FA8Ue7Yl.y02p.Mfnrt/cUhlgrp9R.UhXsN5RfXXmsm22', 'Roberto', 'Perez', '0000001', 'student', '2025-04-17 14:46:06', '2025-04-19 11:15:03', 'INACTIVE');

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
-- Indexes for dumped tables
--

--
-- Indexes for table `answers`
--
ALTER TABLE `answers`
  ADD PRIMARY KEY (`pk_answer`),
  ADD KEY `idx_question_fk` (`question_fk`);

--
-- Indexes for table `level_history`
--
ALTER TABLE `level_history`
  ADD PRIMARY KEY (`pk_history`),
  ADD KEY `idx_level_fk` (`level_fk`),
  ADD KEY `idx_user_fk` (`user_fk`);

--
-- Indexes for table `mcer_level`
--
ALTER TABLE `mcer_level`
  ADD PRIMARY KEY (`pk_level`);

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
  ADD KEY `idx_title_fk` (`title_fk`);

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
  ADD UNIQUE KEY `user_carnet` (`user_carnet`),
  ADD KEY `idx_email` (`user_email`),
  ADD KEY `idx_carnet` (`user_carnet`);

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
  MODIFY `pk_answer` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=17;

--
-- AUTO_INCREMENT for table `level_history`
--
ALTER TABLE `level_history`
  MODIFY `pk_history` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `mcer_level`
--
ALTER TABLE `mcer_level`
  MODIFY `pk_level` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `prompts`
--
ALTER TABLE `prompts`
  MODIFY `pk_prompt` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `questions`
--
ALTER TABLE `questions`
  MODIFY `pk_question` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `questions_titles`
--
ALTER TABLE `questions_titles`
  MODIFY `pk_title` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `recommendations`
--
ALTER TABLE `recommendations`
  MODIFY `pk_recommend` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `strengths`
--
ALTER TABLE `strengths`
  MODIFY `pk_strength` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `study_materials`
--
ALTER TABLE `study_materials`
  MODIFY `pk_studymaterial` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `tests`
--
ALTER TABLE `tests`
  MODIFY `pk_test` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `test_comments`
--
ALTER TABLE `test_comments`
  MODIFY `pk_comment` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `test_details`
--
ALTER TABLE `test_details`
  MODIFY `pk_testdetail` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `toeic_sections`
--
ALTER TABLE `toeic_sections`
  MODIFY `section_pk` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `pk_user` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `weaknesses`
--
ALTER TABLE `weaknesses`
  MODIFY `pk_weakness` int(11) NOT NULL AUTO_INCREMENT;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `answers`
--
ALTER TABLE `answers`
  ADD CONSTRAINT `answers_ibfk_1` FOREIGN KEY (`question_fk`) REFERENCES `questions` (`pk_question`);

--
-- Constraints for table `level_history`
--
ALTER TABLE `level_history`
  ADD CONSTRAINT `level_history_ibfk_1` FOREIGN KEY (`level_fk`) REFERENCES `mcer_level` (`pk_level`),
  ADD CONSTRAINT `level_history_ibfk_2` FOREIGN KEY (`user_fk`) REFERENCES `users` (`pk_user`);

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

