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
    def create_user(name, user_lastname, carnet, user_email, user_role, password, code, is_verified):
        try:
            # Conexión a la base de datos
            cur = mysql.connection.cursor()
            status = "PENDING"
            # Ejecutar la consulta SQL
            cur.execute("INSERT INTO users (user_name, user_lastname, user_carnet, user_email, user_role, user_password, Status, verification_code, is_verified) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)", 
                        (name, user_lastname, carnet, user_email, user_role, password, status, code, is_verified))
            
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
            cur.execute("""UPDATE users set status = %s where user_email = %s AND status = 'ACTIVE' """, 
                        (status,email))
            
            # Confirmar cambios en la base de datos
            mysql.connection.commit()
            
            return 'True'
        except Exception as e:
           return str(e).lower()
       
       
    @staticmethod
    def activate_user(email):
        try:
       # Conexión a la base de datos
            cur = mysql.connection.cursor()
            status = "ACTIVE"
            # Ejecutar la consulta SQL
            cur.execute("""UPDATE users set status = %s where user_email = %s AND status = 'INACTIVE' """, 
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

                if filters.get("user_carnet"):
                    where_clauses.append("user_carnet LIKE %s")
                    params.append(f"%{filters['user_carnet']}%")

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
                    user_carnet,
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