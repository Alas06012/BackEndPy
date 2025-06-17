from app import mysql

class TestCommentsModel:
    
    @staticmethod
    def add_comment(test_id, user_id, comment_title, comment_value):
        #Agrega un comentario a un test específico.
        cur = mysql.connection.cursor()
        query = """
            INSERT INTO test_comments (comment_title, comment_value, user_fk, test_fk)
            VALUES (%s, %s, %s, %s)
        """
        values = (comment_title, comment_value, user_id, test_id)

        try:
            cur.execute(query, values)
            mysql.connection.commit()
            return cur.rowcount > 0
        except Exception as e:
            print("Error al insertar comentario:", e)
            return False
        
        
        
    @staticmethod
    def get_comments_by_test_id(test_id):
        cur = mysql.connection.cursor()
        query = """
            SELECT 
                tc.pk_comment,
                tc.comment_title,
                tc.comment_value,
                tc.created_at,
                u.user_email AS author
            FROM test_comments tc
            JOIN users u ON tc.user_fk = u.pk_user
            WHERE tc.test_fk = %s
            ORDER BY tc.created_at DESC
        """
        try:
            cur.execute(query, (test_id,))
            return cur.fetchall()
            
        except Exception as e:
            print("Error al obtener comentarios:", e)
            return []
        
        
    @staticmethod
    def update_comment_by_id(comment_id, user_id, new_title, new_value):
        cur = mysql.connection.cursor()
        query = """
            UPDATE test_comments 
            SET comment_title = %s, comment_value = %s 
            WHERE pk_comment = %s AND user_fk = %s
        """
        try:
            cur.execute(query, (new_title, new_value, comment_id, user_id))
            mysql.connection.commit()
            return cur.rowcount > 0
        except Exception as e:
            print("Error al actualizar comentario:", e)
            return False
        
        
        
    @staticmethod
    def update_ai_comment(testdetail_id, comment_json):
        try:
            cur = mysql.connection.cursor()
            cur.execute("""
                UPDATE test_details 
                SET ai_comments = %s 
                WHERE pk_testdetail = %s
            """, (comment_json, testdetail_id))
            mysql.connection.commit()
            return cur.rowcount > 0
        except Exception as e:
            print(f"Error al actualizar ai_comments: {str(e)}")
            mysql.connection.rollback()
            return False
        finally:
            cur.close()
