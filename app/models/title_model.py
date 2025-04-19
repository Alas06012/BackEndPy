from app import mysql

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
    def inactivate_questions_per_title(title_id):
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
       
       
    