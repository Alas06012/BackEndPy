from app import mysql

class UserLevelhistory:
    
    @staticmethod
    def save_user_level(current_user_id, mcer_level):
        try:
            cur = mysql.connection.cursor()

            # Inicia la transacción
            mysql.connection.begin()
            
            query1 = f""""""
            cur.execute("""
                        SELECT pk_level FROM mcer_level WHERE lower(level_name) = lower(%s)
                        """, 
                        (mcer_level))
            user_level = list(cur.fetchone().values())[0]

            # Insertar 
            cur.execute("""
                        INSERT INTO level_history (user_fk, level_fk) 
                        VALUES (%s, %s)
                        """,
                        (current_user_id, user_level))

            # Confirmar cambios
            mysql.connection.commit()

            return 'True'
        except Exception as e:
            # Si hay un error, hacer rollback para deshacer todo
            mysql.connection.rollback()
            return str(e).lower()