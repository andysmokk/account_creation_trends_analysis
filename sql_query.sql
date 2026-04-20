-- Extract account-related data

WITH account_data AS (
  SELECT
    s.date,
    sp.country,
    a.send_interval,
    a.is_verified,
    a.is_unsubscribed,

    COUNT(a.id) AS account_cnt
  FROM
    `data-analytics-mate.DA.account` a
  JOIN
    `data-analytics-mate.DA.account_session` acs
  ON
    a.id = acs.account_id
  JOIN
    `data-analytics-mate.DA.session` s
  ON
    acs.ga_session_id = s.ga_session_id
  JOIN
    `data-analytics-mate.DA.session_params` sp
  ON
    s.ga_session_id = sp.ga_session_id
  GROUP BY
    s.date,
    sp.country,
    a.send_interval,
    a.is_verified,
    a.is_unsubscribed
),


-- Extract email event data (sent, opened, visited)

emails_data AS (
SELECT
  DATE_ADD(s.date, INTERVAL es.sent_date DAY) AS sent_date,

  sp.country,
  a.send_interval,
  a.is_verified,
  a.is_unsubscribed,

  COUNT(es.id_message) AS sent_msg,
  COUNT(eo.id_message) AS open_msg,
  COUNT(ev.id_message) AS visit_msg
FROM
    `data-analytics-mate.DA.email_sent` es
  LEFT JOIN
    `data-analytics-mate.DA.email_open` eo
  ON
    es.id_message = eo.id_message
  LEFT JOIN
    `data-analytics-mate.DA.email_visit` ev
  ON
    es.id_message = ev.id_message
  JOIN
    `data-analytics-mate.DA.account_session` acs
  ON
    es.id_account = acs.account_id
  JOIN
    `data-analytics-mate.DA.session` s
  ON
    acs.ga_session_id = s.ga_session_id
  JOIN
    `data-analytics-mate.DA.session_params` sp
  ON
    acs.ga_session_id = sp.ga_session_id
  JOIN
    `data-analytics-mate.DA.account` a
  ON
    acs.account_id = a.id
  GROUP BY
    s.date,
    es.sent_date,
    sp.country,
    a.send_interval,
    a.is_verified,
    a.is_unsubscribed
),


-- Merge account and email data

merging_data AS (
SELECT
  date,
  country,
  send_interval,
  is_verified,
  is_unsubscribed,
  account_cnt,

  0 AS sent_msg,
  0 AS open_msg,
  0 AS visit_msg
FROM
  account_data

UNION ALL

SELECT
  sent_date,
  country,
  send_interval,
  is_verified,
  is_unsubscribed,
  0 AS account_cnt,

  sent_msg,
  open_msg,
  visit_msg
FROM
  emails_data
),


-- Aggregate the merged data

final_groups_data AS (
SELECT
  date,
  country,
  send_interval,
  is_verified,
  is_unsubscribed,

  SUM(account_cnt) AS account_cnt,
  SUM(sent_msg) AS sent_msg,
  SUM(open_msg) AS open_msg,
  SUM(visit_msg) AS visit_msg
FROM
  merging_data
GROUP BY
  date,
  country,
  send_interval,
  is_verified,
  is_unsubscribed
),


-- Calculate total accounts and sent emails per country

sums_data AS (
SELECT
  date,
  country,
  account_cnt,
  sent_msg,
  open_msg,
  visit_msg,
  total_country_account_cnt,
  total_country_sent_cnt,

  DENSE_RANK() OVER (ORDER BY total_country_account_cnt DESC) AS rank_total_country_account_cnt,
  DENSE_RANK() OVER (ORDER BY total_country_sent_cnt DESC) AS rank_total_country_sent_cnt,
FROM (
  SELECT
    date,
    country,
    account_cnt,
    sent_msg,
    open_msg,
    visit_msg,

    SUM(account_cnt) OVER (PARTITION BY country) AS total_country_account_cnt,
    SUM(sent_msg) OVER (PARTITION BY country) AS total_country_sent_cnt,
  FROM
    final_groups_data
))


-- Select top 10 ranked countries by accounts or sent emails

SELECT
  *
FROM
  sums_data
WHERE
  rank_total_country_account_cnt <= 10
OR
  rank_total_country_sent_cnt <= 10
