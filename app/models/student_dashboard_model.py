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
            print(f"Conexión a MySQL establecida: {mysql.connection.open}")  # Depuración de conexión

            # Llamar al procedimiento almacenado
            cur.callproc('get_user_diagnostic_stats', [user_id])
            result = cur.fetchone()

            if not result:
                print("No se encontraron datos para el usuario")
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

            # Procesar last_5_tests (cadena simulada como JSON)
            if result['last_5_tests']:
                try:
                    test_history_raw = result['last_5_tests'].strip('[]')
                    if test_history_raw:
                        test_history_items = re.findall(r'\{[^}]*\}', test_history_raw)  # Extraer cada objeto {}
                        test_history = []
                        for item in test_history_items:
                            item = item.strip('{}')
                            pairs = [pair.strip() for pair in item.split(',') if ': ' in pair]
                            score_date = {}
                            for pair in pairs:
                                key, value = pair.split(': ', 1)
                                if key == '"score"':
                                    score_date['score'] = int(value)
                                elif key == '"date"':
                                    score_date['date'] = value.strip('"')
                            if 'score' in score_date and 'date' in score_date:
                                test_history.append({
                                    "score": score_date['score'],
                                    "date": score_date['date']
                                })
                        dashboard_data["test_history"] = test_history[:5]
                    else:
                        dashboard_data["test_history"] = []
                except Exception as e:
                    print(f"Error al parsear test_history: {e} - Raw data: {result['last_5_tests']}")
                    dashboard_data["test_history"] = []

            # Procesar recommendations, strengths, weaknesses
            if result['recommendations']:
                dashboard_data["recommendations"] = [item.strip() for item in result['recommendations'].split(', ') if item.strip()]
            if result['strengths']:
                dashboard_data["strengths"] = [item.strip() for item in result['strengths'].split(', ') if item.strip()]
            if result['weaknesses']:
                dashboard_data["weaknesses"] = [item.strip() for item in result['weaknesses'].split(', ') if item.strip()]

            print(f"Dashboard data: {dashboard_data}")  # Depuración
            return dashboard_data

        except Exception as e:
            print(f"Error al obtener datos del dashboard: {e} - Conexión abierta: {mysql.connection.open}")
            return None
        finally:
            cur.close()
            print(f"Cursor cerrado. Conexión abierta: {mysql.connection.open}")  # Depuración de cierre