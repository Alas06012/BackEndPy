from app import mysql
import MySQLdb

class SectionModel:

    @staticmethod
    def create_section(section_type, section_desc):
        try:
            cur = mysql.connection.cursor()
            cur.execute("""
                INSERT INTO section (type_, section_desc)
                VALUES (%s, %s)
            """, (section_type, section_desc))
            mysql.connection.commit()
            return True
        except Exception as e:
            return str(e).lower()

    @staticmethod
    def edit_section(section_pk, **kwargs):
        try:
            if not kwargs:
                return "No fields to update."

            fields = []
            values = []

            for field, value in kwargs.items():
                fields.append(f"{field} = %s")
                values.append(value)

            values.append(section_pk)

            query = f"""
                UPDATE section
                SET {', '.join(fields)}
                WHERE section_pk = %s
            """

            cur = mysql.connection.cursor()
            cur.execute(query, values)
            mysql.connection.commit()
            return True
        except Exception as e:
            return str(e).lower()

    @staticmethod
    def delete_section(section_pk):
        try:
            cur = mysql.connection.cursor()
            cur.execute("DELETE FROM  toeic_sections WHERE section_pk = %s", (section_pk,))
            mysql.connection.commit()
            return True
        except Exception as e:
            return str(e).lower()

    @staticmethod
    def get_section_by_id(section_pk):
        cur = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
        cur.execute("SELECT * FROM  toeic_sections WHERE section_pk = %s", (section_pk,))
        return cur.fetchone()

    @staticmethod
    def get_all_sections():
        cur = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
        cur.execute("SELECT * FROM  toeic_sections  ORDER BY section_pk ASC")
        return cur.fetchall()

    @staticmethod
    def get_paginated_sections(page=1, per_page=10, search=None):
        try:
            cur = mysql.connection.cursor(MySQLdb.cursors.DictCursor)

            params = []
            where_clause = ""
            if search:
                where_clause = "WHERE section_desc LIKE %s OR type_ LIKE %s"
                search_term = f"%{search}%"
                params.extend([search_term, search_term])

            count_query = f"SELECT COUNT(*) AS total FROM  toeic_sections {where_clause}"
            cur.execute(count_query, tuple(params))
            total = cur.fetchone()['total']

            offset = (page - 1) * per_page
            query = f"""
                SELECT * FROM  toeic_sections
                {where_clause}
                ORDER BY section_pk DESC
                LIMIT %s OFFSET %s
            """
            cur.execute(query, tuple(params + [per_page, offset]))
            data = cur.fetchall()

            return {
                'data': data,
                'total': total,
                'pages': max(1, (total + per_page - 1) // per_page)
            }
        except Exception as e:
            return str(e)
