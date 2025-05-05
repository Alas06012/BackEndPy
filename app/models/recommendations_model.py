from app import mysql

class Recommendations:
    
    @staticmethod
    def save_user_recommendations(test_id, recommendations):
        try:
            cur = mysql.connection.cursor()

            # Inicia la transacción
            mysql.connection.begin()

            # Insertar 
            cur.execute("""
                        INSERT INTO recommendations (test_fk, recommendation_text) 
                        VALUES (%s, %s)
                        """,
                        (test_id, recommendations))

            # Confirmar cambios
            mysql.connection.commit()

            return 'True'
        except Exception as e:
            # Si hay un error, hacer rollback para deshacer todo
            mysql.connection.rollback()
            return str(e).lower()