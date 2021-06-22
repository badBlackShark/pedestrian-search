-- +micrate Up
CREATE TABLE websites (
  id BIGSERIAL PRIMARY KEY,
  date TIMESTAMP,
  description VARCHAR,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);


-- +micrate Down
DROP TABLE IF EXISTS websites;
