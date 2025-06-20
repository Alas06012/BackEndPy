from flask import jsonify, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from app.models.testdetail_model import TestDetail
from app.models.user_model import Usuario

class TestDetailController:
    @staticmethod
    @jwt_required()
    def get_test_details_with_answers():
        try:
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)

            if user['user_role'] not in ['admin', 'teacher','student']:
                return jsonify({"message": "Insufficient permissions"}), 403

            data = request.get_json() or {}
            test_id = data.get('test_id')

            if not test_id:
                return jsonify({"message": "Por favor, proporciona el ID del test"}), 400

            raw_data = TestDetail.get_by_test_id(test_id)

            if not raw_data:
                return jsonify({"message": "No se encontraron detalles para este test"}), 404

            sections = {}
            for row in raw_data:
                try:
                    # Extraer valores de la fila
                    section_type = row['section_type']
                    section_desc = row['section_desc']
                    title_id = row['title_id']
                    title_name = row['title_name']
                    title_test = row['title_test']
                    title_type = row['title_type']
                    title_url = row['title_url']
                    testdetail_id = row['testdetail_id']  # <-- Nuevo campo
                    question_id = row['question_id']
                    question_text = row['question_text']
                    answer_id = row['answer_id']
                    answer_text = row['answer_text']
                    is_correct = row['is_correct']
                    selected_answer_id = row['selected_answer_id']
                    ai_comments = row['ai_comments'] 

                    # FIX: usar una clave compuesta para distinguir secciones correctamente
                    section_key = f"{section_type}::{section_desc}"

                    if section_key not in sections:
                        sections[section_key] = {
                            'section_type': section_type,
                            'section_desc': section_desc,
                            'titles': {}
                        }

                    if title_id not in sections[section_key]['titles']:
                        sections[section_key]['titles'][title_id] = {
                            'title_id': title_id,
                            'title_name': title_name,
                            'title_test': title_test,
                            'title_type': title_type,
                            'title_url': title_url,
                            'questions': {}
                        }

                    if question_id not in sections[section_key]['titles'][title_id]['questions']:
                        sections[section_key]['titles'][title_id]['questions'][question_id] = {
                            'question_id': question_id,
                            'question_text': question_text,
                            'testdetail_id': testdetail_id,  
                            'options': [],
                            'student_answer': None,
                            'correct_answer': None,
                            'ai_comments': ai_comments
                        }

                    # Agregar opción
                    option = {
                        'option_id': answer_id,
                        'text': answer_text,
                        'is_correct': bool(is_correct)
                    }
                    sections[section_key]['titles'][title_id]['questions'][question_id]['options'].append(option)

                    # Marcar respuesta seleccionada por el estudiante
                    if selected_answer_id and selected_answer_id == answer_id:
                        sections[section_key]['titles'][title_id]['questions'][question_id]['student_answer'] = {
                            'option_id': answer_id,
                            'text': answer_text
                        }

                    # Marcar respuesta correcta
                    if is_correct:
                        sections[section_key]['titles'][title_id]['questions'][question_id]['correct_answer'] = {
                            'option_id': answer_id,
                            'text': answer_text
                        }

                except KeyError as e:
                    print(f"Clave no encontrada en row: {e}, row: {row}")
                    raise
                except Exception as e:
                    print(f"Error procesando fila: {e}, row: {row}")
                    raise

            # Construir respuesta final
            response_data = []
            for section_key, section_data in sections.items():
                section = {
                    'section_type': section_data['section_type'],
                    'section_desc': section_data['section_desc'],
                    'titles': []
                }
                for title_id, title_data in section_data['titles'].items():
                    title = {
                        'title_id': title_id,
                        'title_name': title_data['title_name'],
                        'title_test': title_data['title_test'],
                        'title_type': title_data['title_type'],
                        'title_url': title_data['title_url'],
                        'questions': []
                    }
                    for question_id, question_data in title_data['questions'].items():
                        title['questions'].append({
                            'question_id': question_id,
                            'question_text': question_data['question_text'],
                            'testdetail_id': question_data['testdetail_id'],  # <-- Aquí lo agregamos
                            'options': question_data['options'],
                            'student_answer': question_data['student_answer'],
                            'correct_answer': question_data['correct_answer'],
                            'ai_comments': question_data['ai_comments']
                        })
                    section['titles'].append(title)
                response_data.append(section)

            return jsonify({"data": response_data}), 200

        except Exception as e:
            print(f"Internal server error: {str(e)}")
            return jsonify({"error": "Internal server error", "details": str(e)}), 500