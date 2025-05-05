from app import mysql

class Strengths:
    
    @staticmethod
    def save_user_strenghts(test_id, strenghts):
        try:
            cur = mysql.connection.cursor()

            # Inicia la transacción
            mysql.connection.begin()

            # Insertar 
            cur.execute("""
                        INSERT INTO strengths (test_fk, strength_text) 
                        VALUES (%s, %s)
                        """,
                        (test_id, strenghts))

            # Confirmar cambios
            mysql.connection.commit()

            return 'True'
        except Exception as e:
            # Si hay un error, hacer rollback para deshacer todo
            mysql.connection.rollback()
            return str(e).lower()