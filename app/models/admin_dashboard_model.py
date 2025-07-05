from app import mysql
import json
import re

class AdminDashboardModel:
    @staticmethod
    def get_dashboard_data():
        """
        Llama al procedimiento almacenado get_admin_dashboard_stats
        y devuelve los datos del dashboard del administrador.
        """
        cur = mysql.connection.cursor()
        try:
            cur.callproc('get_admin_dashboard_stats')
            result = cur.fetchone()

            if not result:
                return None

            # Parsear los campos JSON simulados (tipo texto)
            def parse_json_list(raw):
                try:
                    raw = raw.strip()
                    return json.loads(raw) if raw else []
                except Exception as e:
                    #print(f"Error parseando JSON: {e} - Raw: {raw}")
                    return []

            dashboard_data = {
                "evaluated_students": result['evaluated_students'],
                "average_score": result['average_score'],
                "level_distribution": parse_json_list(result['level_distribution']),
                "top_performers": parse_json_list(result['top_performers']),
                "low_performers": parse_json_list(result['low_performers']),
                "latest_evaluated": parse_json_list(result['latest_evaluated']),
                "tests_by_day": parse_json_list(result['tests_by_day']),
                "approval_rate": result['approval_rate']
            }

            #print(dashboard_data)
            return dashboard_data

        except Exception as e:
            #print(f"Error al obtener dashboard del admin: {e}")
            return None
        finally:
            cur.close()
