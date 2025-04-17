from app import mysql

class Usuario:
    @staticmethod
    def get_active_users():
        cur = mysql.connection.cursor()
        cur.execute("""SELECT pk_user, user_name, user_lastname, user_email, user_role, status FROM users WHERE status = 'ACTIVE' """)
        users = cur.fetchall()
        return users
    
    @staticmethod
    def get_inactive_users():
        cur = mysql.connection.cursor()
        cur.execute("""SELECT pk_user, user_name, user_lastname, user_email, user_role, status FROM users WHERE status = 'INACTIVE' """)
        users = cur.fetchall()
        return users

    @staticmethod
    def get_user_by_id(user_id):
        cur = mysql.connection.cursor()
        status = "ACTIVE"
        cur.execute("""SELECT pk_user, user_name, user_lastname, user_email, user_role FROM users WHERE pk_user = %s AND STATUS = %s""", (user_id, status))
        user = cur.fetchone()
        return user
    
    @staticmethod
    def get_user_by_email(email):
        cur = mysql.connection.cursor()
        status = "ACTIVE"
        cur.execute("""SELECT pk_user, user_name, user_lastname, user_email, user_role, user_password FROM users WHERE user_email = %s AND STATUS = %s""", (email,status))
        user = cur.fetchone()
        return user

    @staticmethod
    def create_user(name, user_lastname, carnet, user_email, user_role, password):
        try:
            # Conexión a la base de datos
            cur = mysql.connection.cursor()
            status = "ACTIVE"
            # Ejecutar la consulta SQL
            cur.execute("INSERT INTO users (user_name, user_lastname, user_carnet, user_email, user_role, user_password, Status) VALUES (%s, %s, %s, %s, %s, %s, %s)", 
                        (name, user_lastname, carnet, user_email, user_role, password, status))
            
            # Confirmar cambios en la base de datos
            mysql.connection.commit()
            
            return 'True'
        except Exception as e:
           return str(e).lower()
            

    @staticmethod
    def edit_user(name, user_lastname, carnet, user_role, current_email, new_email = None):
        
        if new_email == None:
            try:
                cur = mysql.connection.cursor()
                cur.execute("UPDATE users SET user_name = %s, user_lastname = %s,  user_carnet = %s, user_role=%s WHERE user_email = %s", 
                            (name, user_lastname, carnet, user_role, current_email))
                mysql.connection.commit()
                return 'True'
            except Exception as e:
                return str(e).lower()
        else:
            try:
                cur = mysql.connection.cursor()
                cur.execute("UPDATE users SET user_name = %s, user_lastname = %s, user_carnet = %s, user_role=%s, user_email=%s WHERE user_email = %s", 
                            (name, user_lastname, carnet, user_role, new_email, current_email))
                mysql.connection.commit()
                return 'True'
            except Exception as e:
                return str(e).lower()
        
       
   
        

    @staticmethod
    def delete_user(email):
        try:
       # Conexión a la base de datos
            cur = mysql.connection.cursor()
            status = "INACTIVE"
            # Ejecutar la consulta SQL
            cur.execute("""UPDATE users set status = %s where user_email = %s""", 
                        (status,email))
            
            # Confirmar cambios en la base de datos
            mysql.connection.commit()
            
            return 'True'
        except Exception as e:
           return str(e).lower()
