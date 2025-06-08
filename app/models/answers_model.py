from app import mysql

class Answers:
    @staticmethod
    def create_answer(fk_question, answer_text, is_correct):
        try:
            cur = mysql.connection.cursor()
            cur.execute("""
                INSERT INTO answers (question_fk, answer_text, is_correct)
                VALUES (%s, %s, %s)
            """, (fk_question, answer_text, is_correct))
            mysql.connection.commit()
            
            return 'True'
        except Exception as e:
           return str(e).lower()
       
       
    @staticmethod
    def create_bulk_answers(answers_list):
        try:
            cur = mysql.connection.cursor()
            
            # Preparamos la consulta SQL para múltiples inserciones
            query = """
                INSERT INTO answers (question_fk, answer_text, is_correct)
                VALUES (%s, %s, %s)
            """
            # Preparamos los datos en una lista de tuplas
            data = [(ans["question_id"], ans["text"], ans["is_correct"]) for ans in answers_list]
            
            # Ejecutamos todas las inserciones en una sola transacción
            cur.executemany(query, data)
            mysql.connection.commit()
            
            return 'True'
        except Exception as e:
            mysql.connection.rollback()  # Revertir en caso de error
            return str(e).lower()
        
        
    @staticmethod
    def edit_answer(id_, **kwargs):
        try:
            if not kwargs:
                return "No hay campos para actualizar."

            fields = []
            values = []

            for field, value in kwargs.items():
                fields.append(f"{field} = %s")
                values.append(value)

            values.append(id_)  # el ID al final para el WHERE

            query = f"""
                UPDATE answers
                SET {', '.join(fields)}
                WHERE pk_answer = %s
            """

            cur = mysql.connection.cursor()
            cur.execute(query, values)
            mysql.connection.commit()
            return 'True'
        except Exception as e:
            mysql.connection.rollback()
            return str(e).lower()
        
        
    @staticmethod
    def delete_all_answers(question_id):
        try:
            cur = mysql.connection.cursor()
            cur.execute("""
                DELETE FROM answers
                WHERE question_fk = %s
            """, (question_id,))
            mysql.connection.commit()
            return 'True'
        except Exception as e:
            mysql.connection.rollback()
            return str(e).lower()
        
        
    @staticmethod
    def get_paginated_answers(status, page=1, per_page=20, question_id=None):
        try:
            conn = mysql.connection
            cur = conn.cursor()

            # Construir consulta COUNT
            count_query = "SELECT COUNT(*) FROM answers WHERE status = %s"
            count_params = [status]
            
            if question_id is not None:
                count_query += " AND question_fk = %s"
                count_params.append(question_id)

            # Ejecutar COUNT
            cur.execute(count_query, count_params)
            row = cur.fetchone()
            total = list(row.values())[0] if row else 0


            # Construir consulta principal
            data_query = """
                SELECT 
                    pk_answer,
                    question_fk as question_id,
                    answer_text as text,
                    is_correct,
                    created_at,
                    status
                FROM answers
                WHERE status = %s
            """
            data_params = [status]
            
            if question_id is not None:
                data_query += " AND question_fk = %s"
                data_params.append(question_id)

            # Paginación
            data_query += " LIMIT %s OFFSET %s"
            offset = (page - 1) * per_page
            data_params.extend([per_page, offset])

            # Ejecutar consulta principal
            cur.execute(data_query, data_params)
            data = cur.fetchall()  # Los resultados ya vienen como diccionarios

            return {
                'data': data,
                'total': total,
                'pages': max(1, (total + per_page - 1) // per_page)  # Evitar division por 0
            }

        except Exception as e:
            # Log del error para diagnóstico
            print(f"Error en get_paginated_answers: {str(e)}")
            return str(e)
         
    @staticmethod
    def get_inactive_answers():
        cur = mysql.connection.cursor()
        cur.execute("""
            SELECT 
                * 
            FROM answers 
            WHERE status = %s
        """, ("INACTIVE",))
        questions = cur.fetchall()
        return questions  
    
    
    @staticmethod
    def get_active_answers():
        cur = mysql.connection.cursor()
        cur.execute("""
            SELECT 
                * 
            FROM answers 
            WHERE status = %s
        """, ("ACTIVE",))
        questions = cur.fetchall()
        return questions 
    
    
    @staticmethod
    def get_answers_per_question(question_id):
        cur = mysql.connection.cursor()
        cur.execute("""
            SELECT 
                *
            FROM answers 
            WHERE question_fk = %s
        """, (question_id,))
        questions = cur.fetchall()
        return questions 
        