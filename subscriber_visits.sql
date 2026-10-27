WITH
  subscribers AS (
    SELECT acs.account_id, MIN(date) AS account_created_date
    FROM `data-analytics-mate.DA.account_session` AS acs
    LEFT JOIN `DA.account` AS ac
      ON acs.account_id = ac.id
    LEFT JOIN `DA.session` AS s
      ON acs.ga_session_id = s.ga_session_id
    WHERE ac.is_unsubscribed = 0
    GROUP BY acs.account_id
  ),
  visits AS (
    SELECT
      ev.id_account,
      ev.visit_date
    FROM `data-analytics-mate.DA.email_visit` ev
  ),
  cohorts AS (
    SELECT
      account_id,
      account_created_date,
      CASE
        WHEN visit_date IS NULL THEN NULL
        ELSE DATE_ADD(account_created_date, INTERVAL visit_date DAY)
        END AS visit_date,
      DATE_TRUNC(account_created_date, WEEK(Monday)) AS cohort_week
    FROM subscribers
    LEFT JOIN visits
      ON subscribers.account_id = visits.id_account
    ORDER BY account_created_date
  ),
  cohort_indexes AS (
    SELECT
      *,
      CASE
        WHEN visit_date IS NOT NULL
          THEN FLOOR(DATE_DIFF(visit_date, cohort_week, DAY) / 7)
        END AS cohort_index
    FROM cohorts
  )

# -1 cohort_index indicates all users that registered at the beginning of the cohort
SELECT cohort_week, cohort_index, COUNT(DISTINCT account_id) AS active_users
FROM cohort_indexes
WHERE cohort_index IS NOT NULL
GROUP BY cohort_week, cohort_index
UNION DISTINCT
SELECT
  cohort_week, -1 AS cohort_index, COUNT(DISTINCT account_id) AS active_users
FROM cohort_indexes
GROUP BY cohort_week
ORDER BY cohort_week ASC, cohort_index ASC
