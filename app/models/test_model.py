from app import mysql

class Test:
    @staticmethod
    def get_all_test():
        cur = mysql.connection.cursor()
        cur.execute("""SELECT * FROM test """)
        test = cur.fetchall()
        return test
    
    @staticmethod
    def get_test_by_id(test_id):
        cur = mysql.connection.cursor()
        cur.execute("""SELECT * FROM tests WHERE pk_test = %s""", (test_id,))
        test = cur.fetchone()
        return test
    
    @staticmethod
    def create_test(user_fk):
        cur = mysql.connection.cursor()
        cur.execute("""INSERT INTO tests (user_fk) VALUES (%s)""", (user_fk,))
        test_id = cur.lastrowid
        return test_id

    @staticmethod
    def get_random_titles():
        cur = mysql.connection.cursor()
        cur.execute("""
           (
                SELECT * 
                FROM questions_titles qt
                WHERE qt.title_type = 'READING'
                    AND qt.status = 'ACTIVE'
                    AND EXISTS (
                    SELECT 1 
                    FROM questions q 
                    WHERE q.title_fk = qt.pk_title 
                        AND q.status = 'ACTIVE'
                    )
                ORDER BY RAND()
                LIMIT 12
                )
                UNION ALL
                (
                SELECT * 
                FROM questions_titles qt
                WHERE qt.title_type = 'LISTENING'
                    AND qt.status = 'ACTIVE'
                    AND EXISTS (
                    SELECT 1 
                    FROM questions q 
                    WHERE q.title_fk = qt.pk_title 
                        AND q.status = 'ACTIVE'
                    )
                ORDER BY RAND()
                LIMIT 12
                )
        """)
        return cur.fetchall()
    
    
    
    @staticmethod
    def mark_as_checking_answers(test_id):
        #Marca el test como finalizado cambiando el estado a 'CHECKING_ANSWERS'.
        cur = mysql.connection.cursor()
        cur.execute("""
            UPDATE tests
            SET status = 'CHECKING_ANSWERS'
            WHERE pk_test = %s
        """, (test_id,))
        return cur.rowcount
    
    
    @staticmethod
    def mark_as_completed(test_id, test_points, test_passed):
        #Marca el test como finalizado cambiando el estado a 'COMPLETED'.
        cur = mysql.connection.cursor()
        cur.execute("""
            UPDATE tests
            SET status = 'COMPLETED', test_points = %s, test_passed = %s 
            WHERE pk_test = %s
        """, (test_points, test_passed, test_id))
        return cur.rowcount
    
    
    @staticmethod
    def mark_as_failed(test_id):
        try:
            cursor = mysql.connection.cursor()
            mysql.connection.begin()
            cursor.execute(
                """UPDATE tests 
                SET status = %s 
                WHERE pk_test = %s
                """,
                ('FAILED', test_id)
            )
            mysql.connection.commit()
        except Exception as e:
            mysql.connection.rollback()

    
    @staticmethod
    def save_evaluation_results(test_id, user_id, ai_response):
        #Guarda todos los resultados de la evaluación en la base de datos.
        cur = None
        try:
            cur = mysql.connection.cursor()
            mysql.connection.begin()

            # Extraer datos de la respuesta de IA
            mcer_level = ai_response.get('mcer_level', '')
            toeic_score = ai_response.get('toeic_score', 0)
            passed = ai_response.get('passed', False)
            strengths = ai_response.get('strengths', [])
            weaknesses = ai_response.get('weaknesses', [])
            recommendations = ai_response.get('recommendations', [])
            
            # 1. Guardar nivel del usuario (MCER)
            if mcer_level:
                cur.execute(
                    "SELECT pk_level FROM mcer_level WHERE LOWER(level_name) = LOWER(%s)",
                    (mcer_level,)
                )
                level_result = cur.fetchone()

                if level_result:
                    cur.execute(
                        "INSERT INTO level_history (user_fk, level_fk) VALUES (%s, %s)",
                        (user_id, level_result["pk_level"])
                    )

            # 2. Guardar fortalezas, debilidades y recomendaciones
            for strength in strengths:
                cur.execute(
                    "INSERT INTO strengths (test_fk, strength_text) VALUES (%s, %s)",
                    (test_id, strength)
                )

            for weakness in weaknesses:
                cur.execute(
                    "INSERT INTO weaknesses (test_fk, weakness_text) VALUES (%s, %s)",
                    (test_id, weakness)
                )

            for recommendation in recommendations:
                cur.execute(
                    "INSERT INTO recommendations (test_fk, recommendation_text) VALUES (%s, %s)",
                    (test_id, recommendation)
                )

            status = 'COMPLETED'
            print(status ,passed, toeic_score, test_id)
            # 3. Marcar test como completado
            cur.execute(
                """UPDATE tests 
                    SET status = %s, test_passed = %s, test_points = %s, level_fk = %s
                    WHERE pk_test = %s
                """,
                (status ,passed, toeic_score, level_result["pk_level"], test_id)
            )

            mysql.connection.commit()
            return True

        except Exception as e:
            mysql.connection.rollback()
            raise Exception(f"Error al guardar resultados: {str(e)}")
        
        
        
    @staticmethod
    def get_paginated_tests(filters=None, page=1, per_page=20):
        try:
            conn = mysql.connection
            cur = conn.cursor()

            where_clauses = ["1=1"]
            params = []

            if filters:
                if filters.get("user_email"):
                    where_clauses.append("u.user_email LIKE %s")
                    params.append(f"%{filters['user_email']}%")
                if filters.get("user_name"):
                    where_clauses.append("u.user_name LIKE %s")
                    params.append(f"%{filters['user_name']}%")
                if filters.get("user_lastname"):
                    where_clauses.append("u.user_lastname LIKE %s")
                    params.append(f"%{filters['user_lastname']}%")
                if filters.get("test_passed") is not None:
                    where_clauses.append("t.test_passed = %s")
                    params.append(filters['test_passed'])
                if filters.get("level_fk"):
                    where_clauses.append("t.level_fk = %s")
                    params.append(filters["level_fk"])
                if filters.get("level_name"):
                    where_clauses.append("ml.level_name = %s")
                    params.append(filters["level_name"])
                if filters.get("status"):
                    where_clauses.append("t.status = %s")
                    params.append(filters["status"])

            where_clause = " AND ".join(where_clauses)
            offset = (page - 1) * per_page

            count_query = f"""
                SELECT COUNT(*) as total
                FROM tests t
                JOIN users u ON t.user_fk = u.pk_user
                LEFT JOIN mcer_level ml ON t.level_fk = ml.pk_level
                WHERE {where_clause}
            """
            cur.execute(count_query, params)
            total = cur.fetchone()["total"]

            data_query = f"""
                SELECT
                    t.pk_test,
                    u.user_email,
                    u.user_name,
                    u.user_lastname,
                    t.test_points,
                    t.test_passed,
                    t.status,
                    t.created_at,
                    ml.level_name,
                    ml.level_desc
                FROM tests t
                JOIN users u ON t.user_fk = u.pk_user
                LEFT JOIN mcer_level ml ON t.level_fk = ml.pk_level
                WHERE {where_clause}
                ORDER BY t.created_at DESC
                LIMIT %s OFFSET %s
            """
            cur.execute(data_query, params + [per_page, offset])
            data = cur.fetchall()

            return {
                "data": data,
                "total": total,
                "pages": max(1, (total + per_page - 1) // per_page)
            }

        except Exception as e:
            print(f"Error en get_paginated_tests: {str(e)}")
            return str(e)
        
        
    @staticmethod
    def get_test_analysis_by_id(test_id):
        try:
            conn = mysql.connection
            cur = conn.cursor()

            # Obtener fortalezas
            cur.execute("""
                SELECT pk_strength, strength_text
                FROM strengths
                WHERE test_fk = %s
            """, (test_id,))
            strengths = cur.fetchall()

            # Obtener debilidades
            cur.execute("""
                SELECT pk_weakness, weakness_text
                FROM weaknesses
                WHERE test_fk = %s
            """, (test_id,))
            weaknesses = cur.fetchall()

            # Obtener recomendaciones
            cur.execute("""
                SELECT pk_recommend, recommendation_text
                FROM recommendations
                WHERE test_fk = %s
            """, (test_id,))
            recommendations = cur.fetchall()

            return {
                "test_id": test_id,
                "strengths": strengths,
                "weaknesses": weaknesses,
                "recommendations": recommendations
            }

        except Exception as e:
            print(f"Error en get_test_analysis_by_id: {str(e)}")
            return str(e)


    
    
    