create database nec_diagnostics_db;
use nec_diagnostics_db;

CREATE TABLE users (
    pk_user INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_email VARCHAR(100) NOT NULL UNIQUE,
    user_password VARCHAR(100) NOT NULL,
    user_name VARCHAR(100) NOT NULL,
    user_lastname VARCHAR(100) NOT NULL,
    user_carnet VARCHAR(10) NOT NULL UNIQUE,
    user_role VARCHAR(20),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    status VARCHAR(10),
    INDEX idx_email (user_email),
    INDEX idx_carnet (user_carnet)
);

CREATE TABLE mcer_level (
    pk_level INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    level_name VARCHAR(10),
    level_desc VARCHAR(250),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE level_history (
    pk_history INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    level_fk INT(11),
    user_fk INT(11),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
	updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	FOREIGN KEY (level_fk) REFERENCES mcer_level(pk_level),
    FOREIGN KEY (user_fk) REFERENCES users(pk_user),
    INDEX idx_level_fk (level_fk),
    INDEX idx_user_fk (user_fk)
);

CREATE TABLE tests (
    pk_test INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_fk INT(11) NOT NULL,
    test_points INT(10),
    test_passed INT(1) NULL,
    level_fk INT(11) NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_fk) REFERENCES users(pk_user),
    FOREIGN KEY (level_fk) REFERENCES mcer_level(pk_level),
    INDEX idx_user_fk (user_fk),
    INDEX idx_level_fk (level_fk)
);

CREATE TABLE test_comments (
    pk_comment INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    comment_title VARCHAR(100),
    comment_value TEXT,
    user_fk INT(11),
    test_fk INT(11),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_fk) REFERENCES users(pk_user),
    FOREIGN KEY (test_fk) REFERENCES tests(pk_test),
    INDEX idx_user_fk (user_fk),
    INDEX idx_test_fk (test_fk)
);

CREATE TABLE recommendations (
    pk_recommend INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    test_fk INT(11) NOT NULL,
    recommendation_text TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (test_fk) REFERENCES tests(pk_test),
    INDEX idx_test_fk (test_fk)
);

CREATE TABLE strengths (
    pk_strength INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    test_fk INT(11) NOT NULL,
    strength_text TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (test_fk) REFERENCES tests(pk_test),
    INDEX idx_test_fk (test_fk)
);

CREATE TABLE weaknesses (
    pk_weakness INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    test_fk INT(11) NOT NULL,
    weakness_text TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (test_fk) REFERENCES tests(pk_test),
    INDEX idx_test_fk (test_fk)
);

CREATE TABLE prompts (
    pk_prompt INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    prompt_name VARCHAR(50) NOT NULL,
    prompt_value VARCHAR(750) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_prompt_name (prompt_name)
);


CREATE TABLE questions_titles (
    pk_title INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    title_name VARCHAR(20) NOT NULL,
    title_test TEXT NOT NULL,
    title_type VARCHAR(20) NOT NULL,
    title_url VARCHAR(255) NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE questions (
    pk_question INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    question_section VARCHAR(20),
    question_text TEXT,
    title_fk INT(11) NOT NULL,
    level_fk INT(11) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (level_fk) REFERENCES mcer_level(pk_level),
    FOREIGN KEY (title_fk) REFERENCES questions_titles(pk_title),
    INDEX idx_level_fk (level_fk),
    INDEX idx_title_fk (title_fk)
);

CREATE TABLE answers (
    pk_answer INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    question_fk INT(11) NOT NULL,
    answer_text TEXT,
    answer_correct TINYINT(1),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (question_fk) REFERENCES questions(pk_question),
    INDEX idx_question_fk (question_fk),
    INDEX idx_answer_correct (answer_correct)
);

CREATE TABLE test_details (
    pk_testdetail INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    test_fk INT(11) NOT NULL,
    title_fk INT(11) NOT NULL,
    question_fk INT(11) NULL,
    answer_fk INT(11) NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (test_fk) REFERENCES tests(pk_test),
    FOREIGN KEY (question_fk) REFERENCES questions(pk_question),
    FOREIGN KEY (answer_fk) REFERENCES answers(pk_answer),
    INDEX idx_test_fk (test_fk),
    INDEX idx_question_fk (question_fk),
    INDEX idx_answer_fk (answer_fk)
);


CREATE TABLE study_materials (
    pk_studymaterial INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    studymaterial_title VARCHAR(250) NOT NULL,
    studymaterial_desc TEXT,
    studymaterial_type VARCHAR(20),
    studymaterial_url VARCHAR(255),
    level_fk INT(11) NOT NULL,
    studymaterial_tags VARCHAR(200),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (level_fk) REFERENCES mcer_level(pk_level),
    INDEX idx_level_fk (level_fk),
    INDEX idx_title (studymaterial_title),
    INDEX idx_tags (studymaterial_tags)
);

