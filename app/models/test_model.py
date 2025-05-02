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
        cur.execute("""SELECT * FROM test WHERE pk_test = %s""", (test_id,))
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
        """
        Marca el test como finalizado cambiando el estado a 'CHECKING_ANSWERS'.
        """
        cur = mysql.connection.cursor()
        cur.execute("""
            UPDATE tests
            SET status = 'CHECKING_ANSWERS'
            WHERE pk_test = %s
        """, (test_id,))
        return cur.rowcount
    
    
    @staticmethod
    def mark_as_completed(test_id):
        """
        Marca el test como finalizado cambiando el estado a 'COMPLETED'.
        """
        cur = mysql.connection.cursor()
        cur.execute("""
            UPDATE tests
            SET status = 'COMPLETED'
            WHERE pk_test = %s
        """, (test_id,))
        return cur.rowcount
    
    
    