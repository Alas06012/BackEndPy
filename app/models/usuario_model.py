from app import mysql

class Usuario:
    @staticmethod
    def get_active_users():
        cur = mysql.connection.cursor()
        cur.execute("""SELECT id, name, lastname, email, role, status FROM users WHERE status = 'ACTIVE' """)
        users = cur.fetchall()
        return users
    
    @staticmethod
    def get_inactive_users():
        cur = mysql.connection.cursor()
        cur.execute("""SELECT id, name, lastname, email, role, status FROM users WHERE status = 'INACTIVE' """)
        users = cur.fetchall()
        return users

    @staticmethod
    def get_user_by_id(user_id):
        cur = mysql.connection.cursor()
        status = "ACTIVE"
        cur.execute("""SELECT id, name, lastname, email, role FROM users WHERE id = %s AND STATUS = %s""", (user_id, status))
        user = cur.fetchone()
        return user
    
    @staticmethod
    def get_user_by_email(email):
        cur = mysql.connection.cursor()
        status = "ACTIVE"
        cur.execute("""SELECT id, name, lastname, email, role, password FROM users WHERE email = %s AND STATUS = %s""", (email,status))
        user = cur.fetchone()
        return user

    @staticmethod
    def create_user(name, lastname, carnet, email, role, password):
        try:
            # Conexión a la base de datos
            cur = mysql.connection.cursor()
            status = "ACTIVE"
            # Ejecutar la consulta SQL
            cur.execute("INSERT INTO users (name, lastname, carnet, email, role, password, Status) VALUES (%s, %s, %s, %s, %s, %s, %s)", 
                        (name, lastname, carnet, email, role, password, status))
            
            # Confirmar cambios en la base de datos
            mysql.connection.commit()
            
            return 'True'
        except Exception as e:
           return str(e).lower()
            

    @staticmethod
    def edit_user(name, lastname, carnet, role, current_email, new_email = None):
        
        if new_email == None:
            try:
                cur = mysql.connection.cursor()
                cur.execute("UPDATE users SET name = %s, lastname = %s,  carnet = %s, role=%s WHERE email = %s", 
                            (name, lastname, carnet, role, current_email))
                mysql.connection.commit()
                return 'True'
            except Exception as e:
                return str(e).lower()
        else:
            try:
                cur = mysql.connection.cursor()
                cur.execute("UPDATE users SET name = %s, lastname = %s, carnet = %s, role=%s, email=%s WHERE email = %s", 
                            (name, lastname, carnet, role, new_email, current_email))
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
            cur.execute("""UPDATE users set status = %s where email = %s""", 
                        (status,email))
            
            # Confirmar cambios en la base de datos
            mysql.connection.commit()
            
            return 'True'
        except Exception as e:
           return str(e).lower()
