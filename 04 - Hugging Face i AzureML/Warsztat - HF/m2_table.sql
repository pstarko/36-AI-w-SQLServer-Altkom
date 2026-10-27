CREATE TABLE sklep.ReviewSentiment (
    review_id   INT          PRIMARY KEY
                             REFERENCES sklep.Reviews(review_id),
    sentiment   VARCHAR(20)  NOT NULL
                             CHECK (sentiment IN ('POSITIVE', 'NEGATIVE')),
    score       FLOAT        NOT NULL CHECK (score BETWEEN 0 AND 1),
    model_name  VARCHAR(100) NOT NULL
                             DEFAULT 'distilbert-base-uncased-finetuned-sst-2-english',
    scored_at   DATETIME2    NOT NULL DEFAULT SYSDATETIME()
);
GO
