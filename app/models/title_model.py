from app import mysql
import MySQLdb
from flask_mysqldb import MySQL

class QuestionTitle:
    @staticmethod
    def create_title(title, content, type_, url=None):
        try:
            # Conexión a la base de datos
            cur = mysql.connection.cursor()
            status = "ACTIVE"
            # Ejecutar la consulta SQL
            cur.execute("""INSERT INTO questions_titles (title_name, title_test, title_type, title_url) 
                        VALUES (%s, %s, %s, %s)""", 
                        (title, content, type_, url))
            
            # Confirmar cambios en la base de datos
            mysql.connection.commit()
            
            return 'True'
        except Exception as e:
           return str(e).lower()
       
       
    @staticmethod
    def edit_title(id_, **kwargs):
        try:
            if not kwargs:
                return "No fields to update."

            fields = []
            values = []

            for field, value in kwargs.items():
                fields.append(f"{field} = %s")
                values.append(value)

            values.append(id_)  # el ID al final para el WHERE

            query = f"""
                UPDATE questions_titles
                SET {', '.join(fields)}
                WHERE pk_title = %s
            """

            cur = mysql.connection.cursor()
            cur.execute(query, values)
            mysql.connection.commit()
            return 'True'
        except Exception as e:
            return str(e).lower()
        
        
    @staticmethod
    def delete_title(id_):
        try:
       # Conexión a la base de datos
            cur = mysql.connection.cursor()
            status = "INACTIVE"
            # Ejecutar la consulta SQL
            cur.execute("""
                        UPDATE questions_titles 
                        SET status = %s 
                        WHERE pk_title = %s AND status = 'ACTIVE' 
                        """, 
                        (status,id_))
            
            # Confirmar cambios en la base de datos
            mysql.connection.commit()
            
            return 'True'
        except Exception as e:
           return str(e).lower()
       
    
    @staticmethod
    def deactivate_questions_per_title(title_id):
        try:
       # Conexión a la base de datos
            cur = mysql.connection.cursor()
            status = "INACTIVE"
            # Ejecutar la consulta SQL
            cur.execute("""
                        UPDATE questions 
                        SET status = %s 
                        WHERE title_fk = %s AND status = 'ACTIVE' 
                        """, 
                        (status,title_id))
            
            # Confirmar cambios en la base de datos
            mysql.connection.commit()
            
            return 'True'
        except Exception as e:
           return str(e).lower()
       
    @staticmethod
    def activate_questions_per_title(title_id):
        try:
       # Conexión a la base de datos
            cur = mysql.connection.cursor()
            status = "ACTIVE"
            # Ejecutar la consulta SQL
            cur.execute("""
                        UPDATE questions 
                        SET status = %s 
                        WHERE title_fk = %s AND status = 'INACTIVE' 
                        """, 
                        (status,title_id))
            
            # Confirmar cambios en la base de datos
            mysql.connection.commit()
            
            return 'True'
        except Exception as e:
           return str(e).lower()
       
       
       
    @staticmethod
    def get_active_titles():
        cur = mysql.connection.cursor()
        cur.execute("""
            SELECT 
                pk_title, title_name, title_test, title_type, title_url, status 
            FROM questions_titles 
            WHERE status = %s
        """, ("ACTIVE",))
        users = cur.fetchall()
        return users
    
    
    @staticmethod
    def get_inactive_titles():
        cur = mysql.connection.cursor()
        cur.execute("""
            SELECT 
                pk_title, title_name, title_test, title_type, title_url, status 
            FROM questions_titles 
            WHERE status = %s
        """, ("INACTIVE",))
        users = cur.fetchall()
        return users
    
    @staticmethod
    def get_title_by_id(title_id):
        try:
            cur = mysql.connection.cursor()
            cur.execute("""
                SELECT * FROM questions_titles 
                WHERE pk_title = %s
            """, (title_id,))
            result = cur.fetchone()
            return result
        except Exception as e:
            print(f"Error getting title: {str(e)}")
            return None
    
    @staticmethod
    def get_paginated_titles(status, page=1, per_page=20, title_type=None):
        try:
            conn = mysql.connection
            cur = conn.cursor(MySQLdb.cursors.DictCursor)

            # Filtros WHERE
            where_clauses = ["status = %s"]
            params = [status]

            if title_type:
                where_clauses.append("title_type = %s")
                params.append(title_type)

            where_sql = " WHERE " + " AND ".join(where_clauses)

            # Consulta total
            count_query = f"SELECT COUNT(*) as total FROM questions_titles {where_sql}"
            cur.execute(count_query, tuple(params))
            total_result = cur.fetchone()
            total = total_result['total'] if total_result else 0

            # Paginación
            offset = (page - 1) * per_page
            query = f"""
                SELECT 
                    pk_title,
                    title_name,
                    title_test,
                    title_type,
                    title_url,
                    status,
                    created_at,
                    updated_at
                FROM questions_titles
                {where_sql}
                ORDER BY pk_title DESC
                LIMIT %s OFFSET %s
            """
            final_params = params + [per_page, offset]
            cur.execute(query, tuple(final_params))
            data = cur.fetchall()

            return {
                'data': data,
                'total': total,
                'pages': max(1, (total + per_page - 1) // per_page)
            }

        except Exception as e:
            print("Error en get_paginated_titles:", str(e))
            return str(e)

        finally:
            if cur:
                cur.close()
       
       
    