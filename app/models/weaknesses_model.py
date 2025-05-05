from app import mysql

class Weaknesses:
    
    @staticmethod
    def save_user_weaknesses(test_id, weaknesses):
        try:
            cur = mysql.connection.cursor()

            # Inicia la transacción
            mysql.connection.begin()

            # Insertar 
            cur.execute("""
                        INSERT INTO weaknesses (test_fk, weakness_text) 
                        VALUES (%s, %s)
                        """,
                        (test_id, weaknesses))

            # Confirmar cambios
            mysql.connection.commit()

            return 'True'
        except Exception as e:
            # Si hay un error, hacer rollback para deshacer todo
            mysql.connection.rollback()
            return str(e).lower()