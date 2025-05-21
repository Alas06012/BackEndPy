from app import mysql
import MySQLdb
from flask_mysqldb import MySQL


class Questions:
    @staticmethod
    def get_active_questions():
        cur = mysql.connection.cursor()
        cur.execute("""
            SELECT 
                pk_question, question_text, toeic_section_fk, title_fk, level_fk, status 
            FROM questions 
            WHERE status = 'ACTIVE'
        """)
        questions = cur.fetchall()
        return questions

    @staticmethod
    def create_question(title_fk, level_fk, toeic_section_fk, question_text):
        cur = mysql.connection.cursor()
        cur.execute("""
            INSERT INTO questions (title_fk, level_fk, toeic_section_fk, question_text)
            VALUES (%s, %s, %s, %s)
        """, (title_fk, level_fk, toeic_section_fk, question_text))
        mysql.connection.commit()
        return cur.lastrowid

    @staticmethod
    def create_questions_with_answers_bulk(fk_title, questions):
        cur = mysql.connection.cursor()
        try:
            mysql.connection.begin()  # Start transaction

            for q in questions:
                question_text = q.get("question_text")
                question_type_fk = q.get("question_type_fk")
                question_level_fk = q.get("question_level_fk")
                answers = q.get("answers", [])

                if not all([question_text, question_type_fk, question_level_fk]) or not answers:
                    raise Exception("Incomplete data in one of the questions")

                # Insert question
                cur.execute("""
                    INSERT INTO questions (title_fk, level_fk, toeic_section_fk, question_text)
                    VALUES (%s, %s, %s, %s)
                """, (fk_title, question_level_fk, question_type_fk, question_text))
                question_id = cur.lastrowid

                # Insert answers
                for answer in answers:
                    text = answer.get("text")
                    is_correct = answer.get("is_correct", False)
                    if not text:
                        raise Exception("One of the answers does not have text")

                    cur.execute("""
                        INSERT INTO answers (question_fk, answer_text, is_correct)
                        VALUES (%s, %s, %s)
                    """, (question_id, text, is_correct))

            mysql.connection.commit()  # Commit transaction
            return True

        except Exception as e:
            mysql.connection.rollback()  # Rollback transaction in case of error
            raise e

    @staticmethod
    def delete_question(question_id, status):
        try:
                cur = mysql.connection.cursor()
                cur.execute("""
                    UPDATE questions SET status = %s WHERE pk_question = %s
                """, (status, question_id))
                mysql.connection.commit()
                return 'True'
        except Exception as e:
                return str(e)

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

            values.append(id_)  # Add ID for the WHERE clause

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
            WHERE status = 'INACTIVE'
        """)
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
    def get_paginated_questions(status, page=1, per_page=20, title_id=None, level_id=None, toeic_section_id=None,question_text=None):
        try:
            conn = mysql.connection
            cur = conn.cursor(MySQLdb.cursors.DictCursor)
     
            if status == "Todos":
                where_clauses = ["q.status IN (%s, %s)"]
                params = ["ACTIVE", "INACTIVE"]
            else:
                where_clauses = ["q.status = %s"]
                params = [status]

            if title_id is not None:
                where_clauses.append("q.title_fk = %s")
                params.append(title_id)
            if level_id is not None:
                where_clauses.append("q.level_fk = %s")
                params.append(level_id)
            if toeic_section_id is not None:
                where_clauses.append("q.toeic_section_fk = %s")
                params.append(toeic_section_id)
            if question_text:
                where_clauses.append("q.question_text LIKE %s")
                params.append(f"%{question_text}%")

            where_sql = " WHERE " + " AND ".join(where_clauses)

            # Total count query
            count_query = f"""
                SELECT COUNT(*) as total
                FROM questions q
                LEFT JOIN questions_titles t ON q.title_fk = t.pk_title
                LEFT JOIN mcer_level l ON q.level_fk = l.pk_level
                LEFT JOIN toeic_sections s ON q.toeic_section_fk = s.section_pk
                {where_sql}
            """
            cur.execute(count_query, params)
            total = cur.fetchone()['total']

            # Pagination
            offset = (page - 1) * per_page
            paginated_query = f"""
                SELECT 
                    q.pk_question,
                    q.question_text,
                    q.status,
                    q.created_at,
                    q.updated_at,
                    q.title_fk as title_id,
                    t.title_name,
                    q.level_fk as level_id,
                    l.level_name,
                    q.toeic_section_fk as toeic_section_id,
                    s.type_ as type_section,
                    s.section_desc
                FROM questions q
                LEFT JOIN questions_titles t ON q.title_fk = t.pk_title
                LEFT JOIN mcer_level l ON q.level_fk = l.pk_level
                LEFT JOIN toeic_sections s ON q.toeic_section_fk = s.section_pk
                {where_sql}
                ORDER BY q.pk_question DESC
                LIMIT %s OFFSET %s
            """
            cur.execute(paginated_query, params + [per_page, offset])
            questions = cur.fetchall()

            # Get question IDs for answers query
            question_ids = [q['pk_question'] for q in questions]

            answers_map = {}
            if question_ids:
                format_strings = ','.join(['%s'] * len(question_ids))
                cur.execute(f"""
                    SELECT 
                        pk_answer,
                        question_fk,
                        answer_text,
                        is_correct,
                        status,
                        created_at,
                        updated_at
                    FROM answers
                    WHERE question_fk IN ({format_strings}) AND status = 'ACTIVE'
                """, tuple(question_ids))
                answers = cur.fetchall()

                for ans in answers:
                    qid = ans['question_fk']
                    if qid not in answers_map:
                        answers_map[qid] = []
                    answers_map[qid].append({
                        "answer_id": ans["pk_answer"],
                        "answer_text": ans["answer_text"],
                        "is_correct": bool(ans["is_correct"]),
                        "status": ans["status"],
                        "created_at": str(ans["created_at"]),
                        "updated_at": str(ans["updated_at"]),
                    })

            # Associate answers with questions
            for q in questions:
                q['answers'] = answers_map.get(q['pk_question'], [])

            return {
                'data': questions,
                'total': total,
                'pages': max(1, (total + per_page - 1) // per_page)
            }

        except Exception as e:
            print(f"Error in get_paginated_questions: {str(e)}")
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
