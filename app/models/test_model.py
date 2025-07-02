from app import mysql
import random
import pandas as pd

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
    
        # Obtener todos los títulos activos con su tipo y número de preguntas activas
        cur.execute("""
            SELECT 
                qt.pk_title, 
                qt.title_type,
                (
                    SELECT COUNT(*) 
                    FROM questions q 
                    WHERE q.title_fk = qt.pk_title AND q.status = 'ACTIVE'
                ) AS question_count
            FROM questions_titles qt
            WHERE qt.status = 'ACTIVE'
        """)
        
        results = cur.fetchall()
        df = pd.DataFrame(results, columns=["pk_title", "title_type", "question_count"])
        
        # Filtrar títulos con al menos 1 pregunta activa
        df = df[df["question_count"] > 0]
        # Separar por tipo
        reading_df = df[df["title_type"] == "READING"].sample(frac=1).reset_index(drop=True)
        listening_df = df[df["title_type"] == "LISTENING"].sample(frac=1).reset_index(drop=True)

        selected_titles = []
        total_reading = 0
        total_listening = 0
        max_total = 100
        max_per_type = max_total // 2  #+-50 para cada tipo

        # Seleccionar títulos de READING
        for _, row in reading_df.iterrows():
            count = row["question_count"]
            if total_reading + count <= max_per_type:
                selected_titles.append((int(row["pk_title"]), "READING", count))
                total_reading += count
            if total_reading >= max_per_type - 2:  # Permitir llegar a 46, 47, 48
                break

        # Seleccionar títulos de LISTENING
        for _, row in listening_df.iterrows():
            count = row["question_count"]
            if total_listening + count <= max_per_type:
                selected_titles.append((int(row["pk_title"]), "LISTENING", count))
                total_listening += count
            if total_listening >= max_per_type - 2:
                break

        # Si sobra espacio, puedes rellenar con títulos adicionales de cualquiera
        remaining = max_total - (total_reading + total_listening)
        if remaining > 0:
            remaining_df = df[~df["pk_title"].isin([pk for pk, _, _ in selected_titles])]
            remaining_df = remaining_df.sample(frac=1).reset_index(drop=True)

            for _, row in remaining_df.iterrows():
                count = row["question_count"]
                if count <= remaining:
                    selected_titles.append((int(row["pk_title"]), row["title_type"], count))
                    remaining -= count
                if remaining <= 0:
                    break
        # Devolver formato original: lista de tuplas con pk_title
        return [(pk,) for pk, _, _ in selected_titles]
        
            
            
        
    
    
    
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
        print(filters)
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
                    # Nuevos filtros de fecha
                if filters.get("start_date"):
                    where_clauses.append("DATE(t.created_at) >= %s")
                    params.append(filters["start_date"])
                if filters.get("end_date"):
                    where_clauses.append("DATE(t.created_at) <= %s")
                    params.append(filters["end_date"])
                
                # 👇 Filtro especial: si el rol es student, filtra por su user_id
                if filters.get("user_role") == "student":
                    where_clauses.append("t.user_fk = %s")
                    params.append(filters["user_id"])

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
            cur = conn.cursor()  # <-- cursor como diccionario

            # Obtener datos del test
            cur.execute("""
                SELECT 
                    t.pk_test AS test_id,
                    t.test_points AS score,
                    t.test_passed,
                    t.created_at AS date,
                    u.user_name AS user_name,
                    u.user_lastname AS user_lastname,
                    u.user_email AS user_email,
                    l.level_name AS level_name
                FROM tests t
                JOIN users u ON t.user_fk = u.pk_user
                JOIN mcer_level l ON t.level_fk = l.pk_level
                WHERE t.pk_test = %s
            """, (test_id,))
            test_info = cur.fetchone()

            if not test_info:
                return {"error": "Test no encontrado"}

            # Obtener fortalezas
            cur.execute("""
                SELECT pk_strength, strength_text
                FROM strengths
                WHERE test_fk = %s
            """, (test_id,))
            strengths = [{"id": s['pk_strength'], "text": s['strength_text']} for s in cur.fetchall()]

            # Obtener debilidades
            cur.execute("""
                SELECT pk_weakness, weakness_text
                FROM weaknesses
                WHERE test_fk = %s
            """, (test_id,))
            weaknesses = [{"id": w['pk_weakness'], "text": w['weakness_text']} for w in cur.fetchall()]

            # Obtener recomendaciones
            cur.execute("""
                SELECT pk_recommend, recommendation_text
                FROM recommendations
                WHERE test_fk = %s
            """, (test_id,))
            recommendations = [{"id": r['pk_recommend'], "text": r['recommendation_text']} for r in cur.fetchall()]

            return {
                "test_id": test_info['test_id'],
                "score": test_info['score'],
                "test_passed": test_info['test_passed'],
                "date": test_info['date'],
                "user_name": test_info['user_name'],
                "user_lastname": test_info['user_lastname'],
                "user_email": test_info['user_email'],
                "level_name": test_info['level_name'],
                "strengths": strengths,
                "weaknesses": weaknesses,
                "recommendations": recommendations
            }

        except Exception as e:
            print(f"Error en get_test_analysis_by_id: {str(e)}")
            return {"error": str(e)}




    
    
    