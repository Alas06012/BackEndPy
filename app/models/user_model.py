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
        cur.execute("""SELECT pk_user, user_name, user_lastname, user_email, user_role, test_attempts, last_test_attempt_at FROM users WHERE pk_user = %s AND STATUS = %s""", (user_id, status))
        user = cur.fetchone()
        return user
    
    @staticmethod
    def get_user_by_email(email, status = 'ACTIVE'):
        cur = mysql.connection.cursor()
        cur.execute("""SELECT pk_user, user_name, user_lastname, user_email, user_role, user_password, is_verified, last_code_sent_at FROM users WHERE user_email = %s AND STATUS = %s""", (email,status))
        user = cur.fetchone()
        return user

    @staticmethod
    def get_password_change_token(token):
        cur = mysql.connection.cursor()
        cur.execute("""
            SELECT user_id, expires_at FROM password_reset_tokens
            WHERE token = %s
        """, (token,))
        pw_token = cur.fetchone()
        return pw_token

    @staticmethod
    def get_ip_attempts(ip):
        cur = mysql.connection.cursor()
        # Consultar intentos por IP
        cur.execute("""
            SELECT failed_count, blocked_until
            FROM login_attempts_ip
            WHERE ip_address = %s
        """, (ip,))
        n_attempts = cur.fetchone()
        return n_attempts
    
    
    @staticmethod
    def change_password_with_token(hashed_pw, user_id, token):
        try:
            cur = mysql.connection.cursor()

            cur.execute("SELECT * FROM password_reset_tokens WHERE token = %s AND user_id = %s", (token, user_id))
            token_row = cur.fetchone()

            if not token_row:
                mysql.connection.rollback()
                return False

            cur.execute("UPDATE users SET user_password = %s WHERE pk_user = %s", (hashed_pw, user_id))
            cur.execute("DELETE FROM password_reset_tokens WHERE token = %s", (token,))

            mysql.connection.commit()
            return True

        except Exception as e:
            mysql.connection.rollback()
            return False

        

    @staticmethod
    def create_user(name, user_lastname, user_email, user_role, password, code, is_verified, status=None):
        try:
            # Conexión a la base de datos
            cur = mysql.connection.cursor()
            
            if status == None:
                status = "PENDING"
                
            # Ejecutar la consulta SQL
            cur.execute("INSERT INTO users (user_name, user_lastname, user_email, user_role, user_password, Status, verification_code, is_verified) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)", 
                        (name, user_lastname, user_email, user_role, password, status, code, is_verified))
            
            # Confirmar cambios en la base de datos
            mysql.connection.commit()
            
            return 'True'
        except Exception as e:
           return str(e).lower()
       
       
    @staticmethod
    def activate_user_by_code(email, code):
        cursor = mysql.connection.cursor()
        cursor.execute("SELECT verification_code FROM users WHERE user_email = %s", (email,))
        user = cursor.fetchone()

        if user and user['verification_code'] == code:
            cursor.execute("""
                UPDATE users
                SET status = %s, is_verified = %s, verification_code = NULL
                WHERE user_email = %s
            """, ("ACTIVE", True, email))
            mysql.connection.commit()
            cursor.close()
            return True

        cursor.close()
        return False
    
    @staticmethod
    def update_verification_code(email, new_code):
        try:
            cursor = mysql.connection.cursor()
            cursor.execute("""
                UPDATE users 
                SET verification_code = %s, last_code_sent_at = NOW()
                WHERE user_email = %s
            """, (new_code, email))
            mysql.connection.commit()
            cursor.close()
            return True
        except Exception as e:
            print(f"Error updating verification code: {e}")
            return False


            

    @staticmethod
    def edit_user(name, user_lastname, user_role, current_email, new_email = None):
        
        if new_email == None:
            try:
                cur = mysql.connection.cursor()
                cur.execute("UPDATE users SET user_name = %s, user_lastname = %s, user_role=%s WHERE user_email = %s", 
                            (name, user_lastname, user_role, current_email))
                mysql.connection.commit()
                return 'True'
            except Exception as e:
                return str(e).lower()
        else:
            try:
                cur = mysql.connection.cursor()
                cur.execute("UPDATE users SET user_name = %s, user_lastname = %s, user_role=%s, user_email=%s WHERE user_email = %s", 
                            (name, user_lastname, user_role, new_email, current_email))
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
            cur.execute("""UPDATE users set status = %s where user_email = %s AND status = 'ACTIVE' """, 
                        (status,email))
            
            # Confirmar cambios en la base de datos
            mysql.connection.commit()
            
            return 'True'
        except Exception as e:
           return str(e).lower()
       
       
    @staticmethod
    def clean_ip_attempts(ip):
        try:
            cur = mysql.connection.cursor()
            cur.execute("DELETE FROM login_attempts_ip WHERE ip_address = %s", (ip,))
            mysql.connection.commit()
        except Exception as e:
           return str(e).lower()       
       
       
    @staticmethod
    def update_ip_attempt(new_count, now, blocked_until, ip):
        try:
            cur = mysql.connection.cursor()
            cur.execute("""
                UPDATE login_attempts_ip
                SET failed_count = %s, last_attempt = %s, blocked_until = %s
                WHERE ip_address = %s
            """, (new_count, now, blocked_until, ip))
            mysql.connection.commit()
        except Exception as e:
           return str(e).lower()    
       
       
    @staticmethod
    def insert_ip_attempt(ip_address, failed_count, last_attempt, blocked_until):
        try:
            cur = mysql.connection.cursor()
            cur.execute("""
                INSERT INTO login_attempts_ip (ip_address, failed_count, last_attempt, blocked_until)
                VALUES (%s, %s, %s, %s)
            """, (ip_address, failed_count, last_attempt, blocked_until))
            mysql.connection.commit()
        except Exception as e:
           return str(e).lower() 
       
       
       
    @staticmethod
    def insert_password_change_token(pk_user, token, expires_at):
        try:
            cur = mysql.connection.cursor()
            cur.execute("""
                INSERT INTO password_reset_tokens (user_id, token, expires_at)
                VALUES (%s, %s, %s)
            """, (pk_user, token, expires_at))
            mysql.connection.commit()  
        except Exception as e:
           return str(e).lower() 
       
    
    
       
       
       
    @staticmethod
    def activate_user(email):
        try:
       # Conexión a la base de datos
            cur = mysql.connection.cursor()
            status = "ACTIVE"
            # Ejecutar la consulta SQL
            cur.execute("""UPDATE users set status = %s where user_email = %s AND (status = 'INACTIVE' or status ='PENDING') """, 
                        (status,email))
            
            # Confirmar cambios en la base de datos
            mysql.connection.commit()
            
            return 'True'
        except Exception as e:
           return str(e).lower()
       
       
    @staticmethod
    def get_paginated_users(filters=None, page=1, per_page=20):
        try:
            conn = mysql.connection
            cur = conn.cursor()

            where_clauses = ["1=1"]
            params = []

            if filters:
                if filters.get("user_email"):
                    where_clauses.append("user_email LIKE %s")
                    params.append(f"%{filters['user_email']}%")

                if filters.get("user_name"):
                    where_clauses.append("user_name LIKE %s")
                    params.append(f"%{filters['user_name']}%")

                if filters.get("user_lastname"):
                    where_clauses.append("user_lastname LIKE %s")
                    params.append(f"%{filters['user_lastname']}%")

                if filters.get("user_role"):
                    where_clauses.append("user_role = %s")
                    params.append(filters["user_role"])

                if filters.get("status"):
                    where_clauses.append("status = %s")
                    params.append(filters["status"])

            where_clause = " AND ".join(where_clauses)

            # Count
            count_query = f"SELECT COUNT(*) FROM users WHERE {where_clause}"
            cur.execute(count_query, params)
            total = list(cur.fetchone().values())[0]

            # Data
            offset = (page - 1) * per_page
            data_query = f"""
                SELECT
                    pk_user,
                    user_email,
                    user_name,
                    user_lastname,
                    user_role,
                    status,
                    created_at,
                    updated_at
                FROM users
                WHERE {where_clause}
                LIMIT %s OFFSET %s
            """
            cur.execute(data_query, params + [per_page, offset])
            data = cur.fetchall()

            return {
                'data': data,
                'total': total,
                'pages': max(1, (total + per_page - 1) // per_page)
            }

        except Exception as e:
            print(f"Error en get_paginated_users: {str(e)}")
            return str(e)