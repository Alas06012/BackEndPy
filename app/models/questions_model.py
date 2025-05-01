from app import mysql
import MySQLdb
from flask_mysqldb import MySQL

class Questions:
    @staticmethod
    def get_active_questions():
        cur = mysql.connection.cursor()
        cur.execute("""SELECT * FROM questions WHERE status = 'ACTIVE' """)
        questions = cur.fetchall()
        return questions
    
    
    @staticmethod
    def create_question(fk_title, level_fk, question_text, question_type_fk):
        cur = mysql.connection.cursor()
        cur.execute("""
            INSERT INTO questions (title_fk, level_fk, toeic_section_fk, question_text)
            VALUES (%s, %s, %s, %s)
        """, (fk_title, level_fk, question_type_fk, question_text))
        mysql.connection.commit()
        return cur.lastrowid  # ID de la pregunta insertada
    
    
    @staticmethod
    def create_questions_with_answers_bulk(fk_title, questions):
        cur = mysql.connection.cursor()
        try:
            mysql.connection.begin()  # Iniciar transaccion

            for q in questions:
                question_text = q.get("question_text")
                question_type_fk = q.get("question_type_fk")
                question_level_fk = q.get("question_level_fk")
                answers = q.get("answers", [])

                if not all([question_text, question_type_fk, question_level_fk]) or not answers:
                    raise Exception("Datos incompletos en una de las preguntas")

                # Insertar pregunta
                cur.execute("""
                    INSERT INTO questions (title_fk, level_fk, toeic_section_fk, question_text)
                    VALUES (%s, %s, %s, %s)
                """, (fk_title, question_level_fk, question_type_fk, question_text))
                question_id = cur.lastrowid

                # Insertar respuestas
                for answer in answers:
                    text = answer.get("text")
                    is_correct = answer.get("is_correct", False)
                    if not text:
                        raise Exception("Una de las respuestas no tiene texto")

                    cur.execute("""
                        INSERT INTO answers (question_fk, answer_text, is_correct)
                        VALUES (%s, %s, %s)
                    """, (question_id, text, is_correct))

            mysql.connection.commit()  # Todo correcto
            return True

        except Exception as e:
            mysql.connection.rollback()  # Revertir todo si hay error
            raise e
        
        
    @staticmethod
    def delete_question(id_):
        try:
       # Conexión a la base de datos
            cur = mysql.connection.cursor()
            status = "INACTIVE"
            # Ejecutar la consulta SQL
            cur.execute("""
                        UPDATE questions 
                        SET status = %s 
                        WHERE pk_question = %s AND status = 'ACTIVE' 
                        """, 
                        (status,id_))
            
            # Confirmar cambios en la base de datos
            mysql.connection.commit()
            
            return 'True'
        except Exception as e:
           return str(e).lower()
       
       
    @staticmethod
    def edit_question(id_, **kwargs):
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
                UPDATE questions
                SET {', '.join(fields)}
                WHERE pk_question = %s
            """

            cur = mysql.connection.cursor()
            cur.execute(query, values)
            mysql.connection.commit()
            return 'True'
        except Exception as e:
            return str(e).lower()
        
        
    @staticmethod
    def get_inactive_questions():
        cur = mysql.connection.cursor()
        cur.execute("""
            SELECT 
                pk_question, question_text, toeic_section_fk, title_fk, level_fk, status 
            FROM questions 
            WHERE status = %s
        """, ("INACTIVE",))
        questions = cur.fetchall()
        return questions  
    
    
    @staticmethod
    def get_active_questions():
        cur = mysql.connection.cursor()
        cur.execute("""
            SELECT 
                pk_question, question_text, toeic_section_fk, title_fk, level_fk, status 
            FROM questions 
            WHERE status = %s
        """, ("ACTIVE",))
        questions = cur.fetchall()
        return questions 
    
    
    @staticmethod
    def get_questions_per_title(title_id):
        cur = mysql.connection.cursor()
        cur.execute("""
            SELECT 
                pk_question, question_text, toeic_section_fk, title_fk, level_fk, status 
            FROM questions 
            WHERE title_fk = %s
        """, (title_id,))
        questions = cur.fetchall()
        return questions 
    
    
    @staticmethod
    def get_paginated_questions(status, page=1, per_page=20, title_id=None, level_id=None, toeic_section_id=None):
        try:
            conn = mysql.connection
            cur = conn.cursor(MySQLdb.cursors.DictCursor)

            # WHERE dinámico
            where_clauses = ["status = %s"]
            params = [status]

            if title_id is not None:
                where_clauses.append("title_fk = %s")
                params.append(title_id)
            if level_id is not None:
                where_clauses.append("level_fk = %s")
                params.append(level_id)
            if toeic_section_id is not None:
                where_clauses.append("toeic_section_fk = %s")
                params.append(toeic_section_id)

            where_sql = " WHERE " + " AND ".join(where_clauses)

            # Total de elementos
            count_query = f"SELECT COUNT(*) as total FROM questions {where_sql}"
            cur.execute(count_query, params)
            total = cur.fetchone()['total']

            # Paginación
            offset = (page - 1) * per_page
            paginated_query = f"""
                SELECT 
                    pk_question,
                    question_text,
                    title_fk as title_id,
                    level_fk as level_id,
                    toeic_section_fk as toeic_section_id,
                    created_at,
                    updated_at,
                    status
                FROM questions
                {where_sql}
                LIMIT %s OFFSET %s
            """
            cur.execute(paginated_query, params + [per_page, offset])
            data = cur.fetchall()

            return {
                'data': data,
                'total': total,
                'pages': max(1, (total + per_page - 1) // per_page)
            }

        except Exception as e:
            print(f"Error en get_paginated_questions: {str(e)}")
            return str(e)
        finally:
            cur.close()
            
    @staticmethod
    def get_random_questions_by_title(title_id):
        cur = mysql.connection.cursor()
        cur.execute("""
            SELECT pk_question FROM questions
            WHERE title_fk = %s AND status = 'ACTIVE'
            ORDER BY RAND() LIMIT 4
        """, (title_id,))
        return cur.fetchall()        

        
        