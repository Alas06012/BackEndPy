from app import mysql
import json
import re

class StudentDashboardModel:
    @staticmethod
    def get_dashboard_data(user_id):
        """
        Obtiene los datos del dashboard para un estudiante específico basado en su user_id
        usando el procedimiento almacenado get_user_diagnostic_stats.
        """
        cur = mysql.connection.cursor()
        try:
            #print(f"Conexión a MySQL establecida: {mysql.connection.open}")

            # Llamar al procedimiento almacenado
            cur.callproc('get_user_diagnostic_stats', [user_id])
            result = cur.fetchone()

            if not result:
                #print("No se encontraron datos para el usuario")
                return None

            # Extraer los datos del resultado
            dashboard_data = {
                "user_id": result['user_id'],
                "user_name": result['user_name'] or "",
                "user_lastname": result['user_lastname'] or "",
                "current_level": result['english_level'] or "",
                "score": result['last_test_score'] if result['last_test_score'] else 0,
                "test_done": result['tests_completed'] if result['tests_completed'] else 0,
                "test_history": [],
                "recommendations": [],
                "strengths": [],
                "weaknesses": [],
                "rank": result['rank_position'] if result['rank_position'] else 1,
            }

            # Procesar last_5_tests (JSON válido)
            if result['last_5_tests']:
                try:
                    dashboard_data["test_history"] = json.loads(result['last_5_tests'])
                except json.JSONDecodeError as e:
                    #print(f"Error al parsear test_history: {e} - Raw data: {result['last_5_tests']}")
                    dashboard_data["test_history"] = []

            # Procesar recommendations, strengths, weaknesses como JSON
            def parse_json_field(field):
                if field and field != '[]':
                    try:
                        return json.loads(field)
                    except json.JSONDecodeError:
                        # Fallback para datos mal formados
                        return [field.strip('"')] if field else []
                return []

            dashboard_data["recommendations"] = parse_json_field(result['recommendations'])
            dashboard_data["strengths"] = parse_json_field(result['strengths'])
            dashboard_data["weaknesses"] = parse_json_field(result['weaknesses'])

            #print(f"Dashboard data: {dashboard_data}")
            return dashboard_data

        except Exception as e:
           # print(f"Error al obtener datos del dashboard: {e} - Conexión abierta: {mysql.connection.open}")
            return None
        finally:
            cur.close()
           # print(f"Cursor cerrado. Conexión abierta: {mysql.connection.open}")