from app import mysql

class Usuario:
    @staticmethod
    def get_all_users():
        cur = mysql.connection.cursor()
        cur.execute("SELECT id, name, email FROM usuarios")
        users = cur.fetchall()
        return users

    @staticmethod
    def get_user_by_id(user_id):
        cur = mysql.connection.cursor()
        cur.execute("SELECT id, name, email FROM usuarios WHERE id = %s", [user_id])
        user = cur.fetchone()
        return user
    
    @staticmethod
    def get_user_by_email(email):
        cur = mysql.connection.cursor()
        cur.execute("SELECT id, name, email, password FROM usuarios WHERE email = %s", [email])
        user = cur.fetchone()
        return user

    @staticmethod
    def create_user(name, email, password):
        try:
            # Conexión a la base de datos
            cur = mysql.connection.cursor()
            
            # Ejecutar la consulta SQL
            cur.execute("INSERT INTO usuarios (name, email, password) VALUES (%s, %s, %s)", 
                        (name, email, password))
            
            # Confirmar cambios en la base de datos
            mysql.connection.commit()
            
            return 'True'
        except Exception as e:
           return str(e).lower()
            

    @staticmethod
    def update_user(user_id, name, email):
        cur = mysql.connection.cursor()
        cur.execute("UPDATE usuarios SET name = %s, email = %s WHERE id = %s", 
                    (name, email, user_id))
        mysql.connection.commit()

    @staticmethod
    def delete_user(user_id):
        cur = mysql.connection.cursor()
        cur.execute("DELETE FROM usuarios WHERE id = %s", [user_id])
        mysql.connection.commit()
