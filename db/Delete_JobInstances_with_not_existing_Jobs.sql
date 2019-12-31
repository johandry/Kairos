-- View JobInstances with not existing Jobs
SELECT JI.id
FROM JobInstances JI
  LEFT JOIN Jobs J ON JI.job_id = J.id
WHERE J.id IS NULL;

-- Create a Temporary table to get the JobInstances id.
-- This table will be deleted as soon as you disconnect
CREATE TEMPORARY TABLE to_delete AS (
  SELECT JI.id
  FROM JobInstances JI
    LEFT JOIN Jobs J ON JI.job_id = J.id
  WHERE J.id IS NULL
);

-- Delete them. You may double check with the first sentence.
DELETE 
FROM JobInstances
WHERE id IN 
(
  SELECT * FROM to_delete
);