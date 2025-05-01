from app import mysql

class StudyMaterial:
    @staticmethod
    def get_all_study_materials():
        cur = mysql.connection.cursor()
        cur.execute("""
            SELECT 
                pk_studymaterial, 
                studymaterial_title, 
                studymaterial_desc, 
                studymaterial_type, 
                studymaterial_url, 
                level_fk, 
                studymaterial_tags, 
                created_at 
            FROM study_materials
        """)
        materials = cur.fetchall()
        return materials

    @staticmethod
    def get_study_material_by_id(material_id):
        cur = mysql.connection.cursor()
        cur.execute("""
            SELECT 
                pk_studymaterial, 
                studymaterial_title, 
                studymaterial_desc, 
                studymaterial_type, 
                studymaterial_url, 
                level_fk, 
                studymaterial_tags, 
                created_at 
            FROM study_materials 
            WHERE pk_studymaterial = %s
        """, (material_id,))
        material = cur.fetchone()
        return material

    @staticmethod
    def create_study_material(title, description, material_type, url, level_fk, tags):
        try:
            cur = mysql.connection.cursor()
            cur.execute("""
                INSERT INTO study_materials (
                    studymaterial_title, 
                    studymaterial_desc, 
                    studymaterial_type, 
                    studymaterial_url, 
                    level_fk, 
                    studymaterial_tags
                ) VALUES (%s, %s, %s, %s, %s, %s)
            """, (title, description, material_type, url, level_fk, tags))
            
            mysql.connection.commit()
            return 'True'
        except Exception as e:
            return str(e).lower()

    @staticmethod
    def update_study_material(material_id, title, description, material_type, url, level_fk, tags):
        try:
            cur = mysql.connection.cursor()
            cur.execute("""
                UPDATE study_materials SET 
                    studymaterial_title = %s,
                    studymaterial_desc = %s,
                    studymaterial_type = %s,
                    studymaterial_url = %s,
                    level_fk = %s,
                    studymaterial_tags = %s
                WHERE pk_studymaterial = %s
            """, (title, description, material_type, url, level_fk, tags, material_id))
            
            mysql.connection.commit()
            return 'True'
        except Exception as e:
            return str(e).lower()

    @staticmethod
    def delete_study_material(material_id):
        try:
            cur = mysql.connection.cursor()
            cur.execute("DELETE FROM study_materials WHERE pk_studymaterial = %s", (material_id,))
            mysql.connection.commit()
            return 'True'
        except Exception as e:
            return str(e).lower()

    @staticmethod
    def get_paginated_study_materials(filters=None, page=1, per_page=20):
        try:
            conn = mysql.connection
            cur = conn.cursor()

            where_clauses = ["1=1"]
            params = []

            if filters:
                if filters.get("studymaterial_title"):
                    where_clauses.append("studymaterial_title LIKE %s")
                    params.append(f"%{filters['studymaterial_title']}%")
                
                if filters.get("studymaterial_desc"):
                    where_clauses.append("studymaterial_desc LIKE %s")
                    params.append(f"%{filters['studymaterial_desc']}%")
                
                if filters.get("studymaterial_type"):
                    where_clauses.append("studymaterial_type = %s")
                    params.append(filters["studymaterial_type"])
                
                if filters.get("level_fk"):
                    where_clauses.append("level_fk = %s")
                    params.append(filters["level_fk"])
                
                if filters.get("studymaterial_tags"):
                    tags = filters["studymaterial_tags"].split(',')
                    tag_conditions = []
                    for tag in tags:
                        tag_conditions.append("studymaterial_tags LIKE %s")
                        params.append(f"%{tag.strip()}%")
                    where_clauses.append(f"({' OR '.join(tag_conditions)})")

            where_clause = " AND ".join(where_clauses)

            # Obtener total
            count_query = f"SELECT COUNT(*) as total FROM study_materials WHERE {where_clause}"
            cur.execute(count_query, params)
            total = cur.fetchone()['total']

            # Obtener datos paginados
            offset = (page - 1) * per_page
            data_query = f"""
                SELECT 
                    pk_studymaterial,
                    studymaterial_title,
                    studymaterial_desc,
                    studymaterial_type,
                    studymaterial_url,
                    level_fk,
                    studymaterial_tags,
                    created_at
                FROM study_materials
                WHERE {where_clause}
                LIMIT %s OFFSET %s
            """
            cur.execute(data_query, params + [per_page, offset])
            data = cur.fetchall()

            return {
                'data': data,
                'total': total,
                'pages': max(1, (total + per_page - 1) // per_page)
            }

        except Exception as e:
            print(f"Error en get_paginated_study_materials: {str(e)}")
            return str(e)