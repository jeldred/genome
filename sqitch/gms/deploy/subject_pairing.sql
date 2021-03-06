-- Deploy subject_pairing
-- requires: subject_subject
-- requires: config_analysis_project

BEGIN;

CREATE TABLE IF NOT EXISTS subject.pairing (
    id character varying(64) NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    created_by character varying(255) NOT NULL,
    control_subject_id character varying(64) NOT NULL,
    experimental_subject_id character varying(64) NOT NULL,
    analysis_project_id character varying(64) NOT NULL,
    CONSTRAINT pairing_pkey PRIMARY KEY (id),
    CONSTRAINT pairing_control_subject_id_experimental_subject_id_analysis_key
        UNIQUE (control_subject_id, experimental_subject_id, analysis_project_id),
    CONSTRAINT pairing_analysis_project_id_fkey
        FOREIGN KEY (analysis_project_id) REFERENCES config.analysis_project(id),
    CONSTRAINT pairing_control_subject_id_fkey
        FOREIGN KEY (control_subject_id) REFERENCES subject.subject(subject_id),
    CONSTRAINT pairing_experimental_subject_id_fkey
        FOREIGN KEY (experimental_subject_id) REFERENCES subject.subject(subject_id)
);

COMMIT;
