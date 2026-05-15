CREATE TABLE IF NOT EXISTS users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    firebase_uid VARCHAR(150) NOT NULL UNIQUE,
    email VARCHAR(150) NOT NULL UNIQUE,
    full_name VARCHAR(100),
    avatar_url VARCHAR(500),
    phone_number VARCHAR(20),
    status TINYINT NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS user_preferences (
    preference_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    preference_type VARCHAR(100) NOT NULL,
    preference_value VARCHAR(255),
    created_at DATETIME NOT NULL,
    CONSTRAINT fk_user_preferences_user
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    UNIQUE KEY uq_user_preferences_value (
        user_id,
        preference_type,
        preference_value
    ),
    KEY idx_user_preferences_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS tourist_places (
    place_id INT AUTO_INCREMENT PRIMARY KEY,
    place_code VARCHAR(50) NOT NULL UNIQUE,
    place_name VARCHAR(150) NOT NULL,
    province VARCHAR(100),
    address VARCHAR(255),
    latitude DECIMAL(10, 7),
    longitude DECIMAL(10, 7),
    short_description TEXT,
    history_description TEXT,
    opening_hours VARCHAR(255),
    ticket_price VARCHAR(255),
    main_image_url VARCHAR(500),
    status TINYINT NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NULL,
    map_query VARCHAR(500),
    related_place_codes_json TEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS place_images (
    image_id INT AUTO_INCREMENT PRIMARY KEY,
    place_id INT NOT NULL,
    image_url VARCHAR(500) NOT NULL,
    caption VARCHAR(255),
    sort_order INT,
    created_at DATETIME NOT NULL,
    CONSTRAINT fk_place_images_place
        FOREIGN KEY (place_id) REFERENCES tourist_places(place_id) ON DELETE CASCADE,
    KEY idx_place_images_place_id (place_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS place_videos (
    video_id INT AUTO_INCREMENT PRIMARY KEY,
    place_id INT NOT NULL,
    video_title VARCHAR(255) NOT NULL,
    video_url VARCHAR(500) NOT NULL,
    duration INT,
    is_primary TINYINT(1) NOT NULL DEFAULT 1,
    status TINYINT NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL,
    CONSTRAINT fk_place_videos_place
        FOREIGN KEY (place_id) REFERENCES tourist_places(place_id) ON DELETE CASCADE,
    KEY idx_place_videos_place_id (place_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS travel_advices (
    advice_id INT AUTO_INCREMENT PRIMARY KEY,
    place_id INT NOT NULL UNIQUE,
    highlight TEXT,
    best_time_to_visit VARCHAR(255),
    estimated_cost VARCHAR(255),
    suggested_itinerary TEXT,
    travel_notes TEXT,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NULL,
    CONSTRAINT fk_travel_advices_place
        FOREIGN KEY (place_id) REFERENCES tourist_places(place_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS nearby_services (
    service_id INT AUTO_INCREMENT PRIMARY KEY,
    place_id INT NOT NULL,
    service_name VARCHAR(255) NOT NULL,
    service_type VARCHAR(50) NOT NULL,
    address VARCHAR(255),
    latitude DECIMAL(10, 7),
    longitude DECIMAL(10, 7),
    google_place_id VARCHAR(255),
    rating DECIMAL(3, 2),
    created_at DATETIME NOT NULL,
    CONSTRAINT fk_nearby_services_place
        FOREIGN KEY (place_id) REFERENCES tourist_places(place_id) ON DELETE CASCADE,
    KEY idx_nearby_services_place_id (place_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ai_models (
    model_id INT AUTO_INCREMENT PRIMARY KEY,
    model_name VARCHAR(150) NOT NULL,
    model_version VARCHAR(50) NOT NULL,
    model_path VARCHAR(500) NOT NULL,
    labels_path VARCHAR(500),
    accuracy DECIMAL(5, 4),
    top3_accuracy DECIMAL(5, 4),
    confidence_threshold DECIMAL(5, 4) NOT NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL,
    UNIQUE KEY uq_ai_models_name_version (model_name, model_version)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS recognition_histories (
    history_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NULL,
    model_id INT NOT NULL,
    predicted_place_id INT NULL,
    image_url VARCHAR(500),
    image_hash VARCHAR(255),
    confidence DECIMAL(5, 4),
    is_confident TINYINT(1) NOT NULL,
    recognition_status VARCHAR(50) NOT NULL,
    recognized_at DATETIME NOT NULL,
    CONSTRAINT fk_histories_user
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL,
    CONSTRAINT fk_histories_model
        FOREIGN KEY (model_id) REFERENCES ai_models(model_id),
    CONSTRAINT fk_histories_place
        FOREIGN KEY (predicted_place_id) REFERENCES tourist_places(place_id) ON DELETE SET NULL,
    KEY idx_histories_user_id_recognized_at (user_id, recognized_at),
    KEY idx_histories_place_id (predicted_place_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS recognition_candidates (
    candidate_id INT AUTO_INCREMENT PRIMARY KEY,
    history_id INT NOT NULL,
    place_id INT NULL,
    rank_no INT NOT NULL,
    confidence DECIMAL(5, 4) NOT NULL,
    created_at DATETIME NOT NULL,
    CONSTRAINT fk_candidates_history
        FOREIGN KEY (history_id) REFERENCES recognition_histories(history_id) ON DELETE CASCADE,
    CONSTRAINT fk_candidates_place
        FOREIGN KEY (place_id) REFERENCES tourist_places(place_id) ON DELETE SET NULL,
    UNIQUE KEY uq_candidates_history_rank (history_id, rank_no),
    KEY idx_candidates_history_id (history_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS favorite_places (
    favorite_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    place_id INT NOT NULL,
    created_at DATETIME NOT NULL,
    CONSTRAINT fk_favorites_user
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_favorites_place
        FOREIGN KEY (place_id) REFERENCES tourist_places(place_id) ON DELETE CASCADE,
    UNIQUE KEY uq_favorites_user_place (user_id, place_id),
    KEY idx_favorites_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS recognition_feedbacks (
    feedback_id INT AUTO_INCREMENT PRIMARY KEY,
    history_id INT NOT NULL,
    user_id INT NULL,
    predicted_place_id INT NULL,
    correct_place_id INT NULL,
    is_correct TINYINT(1) NOT NULL,
    feedback_content VARCHAR(1000),
    created_at DATETIME NOT NULL,
    CONSTRAINT fk_feedbacks_history
        FOREIGN KEY (history_id) REFERENCES recognition_histories(history_id) ON DELETE CASCADE,
    CONSTRAINT fk_feedbacks_user
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL,
    CONSTRAINT fk_feedbacks_predicted_place
        FOREIGN KEY (predicted_place_id) REFERENCES tourist_places(place_id) ON DELETE SET NULL,
    CONSTRAINT fk_feedbacks_correct_place
        FOREIGN KEY (correct_place_id) REFERENCES tourist_places(place_id) ON DELETE SET NULL,
    KEY idx_feedbacks_history_id (history_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
