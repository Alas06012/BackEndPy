from app import mysql
import json

class StudentDashboardModel:
    @staticmethod
    def get_dashboard_data(user_id):
        """
        Obtiene los datos del dashboard para un estudiante específico basado en su user_id.
        """
        cur = mysql.connection.cursor()
        try:
            print(f"Conexión a MySQL establecida: {mysql.connection.open}")  # Depuración de conexión
            # Obtener datos básicos del usuario
            cur.execute("SELECT pk_user, user_name, user_lastname FROM users WHERE pk_user = %s", (user_id,))
            user_result = cur.fetchone()
            if not user_result:
                print("No se encontró el usuario")
                return None

            user_id, user_name, user_lastname = user_result['pk_user'], user_result['user_name'], user_result['user_lastname']

            # Obtener current_level
            cur.execute("""
                SELECT ml.level_name 
                FROM mcer_level ml 
                JOIN level_history lh ON ml.pk_level = lh.level_fk 
                WHERE lh.user_fk = %s 
                ORDER BY lh.created_at DESC LIMIT 1
            """, (user_id,))
            current_level_result = cur.fetchone()
            print(f"current_level_result: {current_level_result}")  # Depuración detallada
            current_level = current_level_result['level_name'] if current_level_result and 'level_name' in current_level_result else ""
            print(f"current_level: {current_level}")  # Depuración

            # Reiniciar cursor para la siguiente consulta
            cur.close()
            cur = mysql.connection.cursor()

            # Obtener score
            cur.execute("""
                SELECT test_points 
                FROM tests t 
                WHERE t.user_fk = %s AND t.status = 'COMPLETED' 
                ORDER BY t.created_at DESC LIMIT 1
            """, (user_id,))
            score_result = cur.fetchone()
            print(f"score_result: {score_result}")  # Depuración detallada
            score = score_result['test_points'] if score_result and 'test_points' in score_result else 0
            print(f"score: {score}")  # Depuración

            # Reiniciar cursor para la siguiente consulta
            cur.close()
            cur = mysql.connection.cursor()

            # Obtener test_done
            cur.execute("""
                SELECT COUNT(*) as count
                FROM tests t 
                WHERE t.user_fk = %s AND t.status = 'COMPLETED'
            """, (user_id,))
            test_done_result = cur.fetchone()
            print(f"test_done_result: {test_done_result}")  # Depuración detallada
            test_done = test_done_result['count'] if test_done_result and 'count' in test_done_result else 0
            print(f"test_done: {test_done}")  # Depuración

            # Reiniciar cursor para la siguiente consulta
            cur.close()
            cur = mysql.connection.cursor()

            # Obtener test_history_raw (usando tests ordenados por created_at)
            cur.execute("""
    SELECT GROUP_CONCAT(
        CONCAT(
            '{"name": "', DATE_FORMAT(t.created_at, '%%d-%%m-%%Y'), '", "score": "', 
            COALESCE(t.test_points, 0), '"}'
        ) SEPARATOR ';'
    ) as test_history
    FROM tests t
    WHERE t.user_fk = %s AND t.status = 'COMPLETED'
    ORDER BY t.created_at DESC
    LIMIT 5
""", (user_id,))
            test_history_raw_result = cur.fetchone()
            print(f"test_history_raw_result: {test_history_raw_result}")  # Depuración detallada
            test_history_raw = test_history_raw_result['test_history'] if test_history_raw_result and 'test_history' in test_history_raw_result else ""
            print(f"test_history_raw: {test_history_raw}")  # Depuración

            # Reiniciar cursor para la siguiente consulta
            cur.close()
            cur = mysql.connection.cursor()

            # Obtener recommendations
            cur.execute("""
                SELECT GROUP_CONCAT(r.recommendation_text SEPARATOR ';') as recommendations
                FROM recommendations r
                JOIN tests t ON r.test_fk = t.pk_test
                WHERE t.user_fk = %s AND t.status = 'COMPLETED'
                ORDER BY t.created_at DESC LIMIT 1
            """, (user_id,))
            recommendations_result = cur.fetchone()
            print(f"recommendations_result: {recommendations_result}")  # Depuración detallada
            recommendations = recommendations_result['recommendations'] if recommendations_result and 'recommendations' in recommendations_result else ""
            print(f"recommendations: {recommendations}")  # Depuración

            # Reiniciar cursor para la siguiente consulta
            cur.close()
            cur = mysql.connection.cursor()

            # Obtener strengths
            cur.execute("""
                SELECT GROUP_CONCAT(s.strength_text SEPARATOR ';') as strengths
                FROM strengths s
                JOIN tests t ON s.test_fk = t.pk_test
                WHERE t.user_fk = %s AND t.status = 'COMPLETED'
                ORDER BY t.created_at DESC LIMIT 1
            """, (user_id,))
            strengths_result = cur.fetchone()
            print(f"strengths_result: {strengths_result}")  # Depuración detallada
            strengths = strengths_result['strengths'] if strengths_result and 'strengths' in strengths_result else ""
            print(f"strengths: {strengths}")  # Depuración

            # Reiniciar cursor para la siguiente consulta
            cur.close()
            cur = mysql.connection.cursor()

            # Obtener weaknesses
            cur.execute("""
                SELECT GROUP_CONCAT(w.weakness_text SEPARATOR ';') as weaknesses
                FROM weaknesses w
                JOIN tests t ON w.test_fk = t.pk_test
                WHERE t.user_fk = %s AND t.status = 'COMPLETED'
                ORDER BY t.created_at DESC LIMIT 1
            """, (user_id,))
            weaknesses_result = cur.fetchone()
            print(f"weaknesses_result: {weaknesses_result}")  # Depuración detallada
            weaknesses = weaknesses_result['weaknesses'] if weaknesses_result and 'weaknesses' in weaknesses_result else ""
            print(f"weaknesses: {weaknesses}")  # Depuración

            # Reiniciar cursor para la siguiente consulta
            cur.close()
            cur = mysql.connection.cursor()

            # Obtener rank
            cur.execute("""
                SELECT COALESCE((
                    SELECT COUNT(*) + 1
                    FROM tests t2
                    WHERE t2.test_points > (
                        SELECT t3.test_points
                        FROM tests t3
                        WHERE t3.user_fk = %s AND t3.status = 'COMPLETED'
                        ORDER BY t3.created_at DESC LIMIT 1
                    )
                    AND t2.level_fk = (
                        SELECT lh2.level_fk
                        FROM level_history lh2
                        WHERE lh2.user_fk = %s
                        ORDER BY lh2.created_at DESC LIMIT 1
                    )
                    AND t2.status = 'COMPLETED'
                ), 1) as rank
            """, (user_id, user_id))
            rank_result = cur.fetchone()
            print(f"rank_result: {rank_result}")  # Depuración detallada
            rank = rank_result['rank'] if rank_result and 'rank' in rank_result else 1
            print(f"rank: {rank}")  # Depuración

            # Procesar test_history_raw en un array de objetos
            test_history = []
            if test_history_raw:
                test_history_items = test_history_raw.split(";")
                for item in test_history_items:
                    try:
                        parsed_item = json.loads(item)
                        if isinstance(parsed_item, dict) and "score" in parsed_item:
                            test_history.append(parsed_item)
                    except json.JSONDecodeError:
                        continue  # Ignorar elementos inválidos
                test_history = test_history[:5]  # Limitar a 5 después del parseo

            # Convertir cadenas separadas por ; en arrays
            recommendations = [item for item in recommendations.split(";") if item]
            strengths = [item for item in strengths.split(";") if item]
            weaknesses = [item for item in weaknesses.split(";") if item]

            dashboard_data = {
                "user_id": user_id,
                "user_name": user_name or "",
                "user_lastname": user_lastname or "",
                "current_level": current_level,
                "score": score,
                "test_done": test_done,
                "test_history": test_history,
                "recommendations": recommendations,
                "strengths": strengths,
                "weaknesses": weaknesses,
                "rank": rank,
            }
            return dashboard_data
        except Exception as e:
            print(f"Error al obtener datos del dashboard: {e} - Query: Consulta falló en una de las subconsultas. Conexión abierta: {mysql.connection.open}")
            return None
        finally:
            cur.close()
            print(f"Cursor cerrado. Conexión abierta: {mysql.connection.open}")  # Depuración de cierre
