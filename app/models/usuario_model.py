from app import mysql

class Usuario:
    @staticmethod
    def get_all_users():
        cur = mysql.connection.cursor()
        cur.execute("""SELECT id, name, email FROM users""")
        users = cur.fetchall()
        return users

    @staticmethod
    def get_user_by_id(user_id):
        cur = mysql.connection.cursor()
        status = "ACTIVE"
        cur.execute("""SELECT id, name, email FROM users WHERE id = %s AND STATUS = %s""", (user_id, status))
        user = cur.fetchone()
        return user
    
    @staticmethod
    def get_user_by_email(email):
        cur = mysql.connection.cursor()
        status = "ACTIVE"
        cur.execute("""SELECT id, name, email, password FROM users WHERE email = %s AND STATUS = %s""", (email,status))
        user = cur.fetchone()
        return user

    @staticmethod
    def create_user(name, lastname, carnet, email, password):
        try:
            # Conexión a la base de datos
            cur = mysql.connection.cursor()
            status = "ACTIVE"
            # Ejecutar la consulta SQL
            cur.execute("INSERT INTO users (name, lastname, carnet, email, password, Status) VALUES (%s, %s, %s, %s, %s, %s)", 
                        (name, lastname, carnet, email, password, status))
            
            # Confirmar cambios en la base de datos
            mysql.connection.commit()
            
            return 'True'
        except Exception as e:
           return str(e).lower()
            

    @staticmethod
    def update_user(user_id, name, email):
        cur = mysql.connection.cursor()
        cur.execute("UPDATE users SET name = %s, email = %s WHERE id = %s", 
                    (name, email, user_id))
        mysql.connection.commit()

    @staticmethod
    def delete_user(user_id):
        cur = mysql.connection.cursor()
        cur.execute("""UPDATE users SET STATE = 'INACTIVE' WHERE id = %s""", [user_id])
        mysql.connection.commit()
