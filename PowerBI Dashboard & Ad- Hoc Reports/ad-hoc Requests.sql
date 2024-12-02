-- BR1      City Level Fare & Trip Summary Report

# creating View 

-- 1st view
create view city_trip_info as 
select 
   t.city_id, c.city_name ,
   count(t.trip_id) as total_trip ,
   sum(t.fare_amount) as revenue,
   sum(t.distance_travelled_km) as total_distance, 
   round(avg(t.passenger_rating),2) as avg_Prating ,
   round(avg(t.driver_rating),2) as avg_Drating 
from 
fact_trips t join dim_city c 
on t.city_id = c.city_id
group by t.city_id;

-- 2 View
create view  totals as
select 
  count(trip_id) total_trips , 
  sum(distance_travelled_km) as total_distance ,
  ( select count(trip_id) from fact_trips where passenger_type ="new") as new_trip  ,
  ( select count(trip_id) from fact_trips where passenger_type ="repeated") as repeated_trip 
  
from fact_trips

# Final Result

elect 
  city_name , total_trip, 
  round(revenue/total_distance,2) as avg_fare_perKM ,
  round(revenue/total_trip,2) as avg_fare_perTrip , 
  round(total_trip /(select total_trips from totals)*100,2) as trip_contribution
from city_trip_info;



-- BR2              Monthly City Level Trip Target 

# Creating Views
 
-- 1

create view Trip_target_Actual_info as 
select 
  targets_db.monthly_target_trips.* ,
  trips_db.dim_city.city_name as city_name,
  count(trips_db.fact_trip.trip_id)  as total_trip
  
from
 targets_db.monthly_target_trips  
 join  
 trips_db.fact_trip 
 on 
targets_db.monthly_target_trips.city_id = trips_db.fact_trip.city_id
and
targets_db.monthly_target_trips.month= trips_db.fact_trip.month 
join 
trips_db.dim_city 
on
targets_db.monthly_target_trips.city_id = trips_db.dim_city.city_id

group by targets_db.monthly_target_trips.month, targets_db.monthly_target_trips.city_id


-- 2 
create view fact_trip as
select *  , DATE_FORMAT(date,'%Y-%m-01') as month from fact_trips



-- Final Result

select 
  month, city_name ,
  total_target_trips  , total_trip as actual_trips ,
  case 
  when total_trip >= total_target_trips then "above Target" 
  else "Below Target" 
  end as performance_status,
  round(((total_trip - total_target_trips) /total_target_trips)*100 ,2) as '%_difference'
from Trip_target_Actual_info;


-- BR3             City Level Repeated Passengers Trip Frequency Report


SELECT 
    c.city_name,
    ROUND((SUM(CASE WHEN r.trip_count = '2-Trips' THEN r.repeat_passenger_count ELSE 0 END) * 100.0) / SUM(r.repeat_passenger_count), 2) AS "2-Trips",
    ROUND((SUM(CASE WHEN r.trip_count = '3-Trips' THEN r.repeat_passenger_count ELSE 0 END) * 100.0) / SUM(r.repeat_passenger_count), 2) AS "3-Trips",
    ROUND((SUM(CASE WHEN r.trip_count = '4-Trips' THEN r.repeat_passenger_count ELSE 0 END) * 100.0) / SUM(r.repeat_passenger_count), 2) AS "4-Trips",
    ROUND((SUM(CASE WHEN r.trip_count = '5-Trips' THEN r.repeat_passenger_count ELSE 0 END) * 100.0) / SUM(r.repeat_passenger_count), 2) AS "5-Trips",
    ROUND((SUM(CASE WHEN r.trip_count = '6-Trips' THEN r.repeat_passenger_count ELSE 0 END) * 100.0) / SUM(r.repeat_passenger_count), 2) AS "6-Trips",
    ROUND((SUM(CASE WHEN r.trip_count = '7-Trips' THEN r.repeat_passenger_count ELSE 0 END) * 100.0) / SUM(r.repeat_passenger_count), 2) AS "7-Trips",
    ROUND((SUM(CASE WHEN r.trip_count = '8-Trips' THEN r.repeat_passenger_count ELSE 0 END) * 100.0) / SUM(r.repeat_passenger_count), 2) AS "8-Trips",
    ROUND((SUM(CASE WHEN r.trip_count = '9-Trips' THEN r.repeat_passenger_count ELSE 0 END) * 100.0) / SUM(r.repeat_passenger_count), 2) AS "9-Trips",
    ROUND((SUM(CASE WHEN r.trip_count = '10-Trips' THEN r.repeat_passenger_count ELSE 0 END) * 100.0) / SUM(r.repeat_passenger_count), 2) AS "10-Trips"
FROM 
    dim_repeat_trip_distribution r
JOIN 
    dim_city c
ON 
    r.city_id = c.city_id
GROUP BY 
    c.city_name
ORDER BY 
    c.city_name;
    
    
    
-- BR4                   Identify the Cities With the Highest & Lowest Total New Passengers 

# creating Views 

-- 1 For Botttom 3

create view bottom3 as 
select city_id , sum(new_passengers) as tp
from fact_passenger_summary
group by city_id
order by tp asc
limit 3;

-- For Top 3
 
create view top3 as 
select city_id , sum(new_passengers) as tp
from fact_passenger_summary
group by city_id
order by tp desc
limit 3;

-- Final Result

select * ,('top3') as category from top3 
union 
select * , ('bottom3') as category from bottom3




-- BR5                  Identify Months with Highest Revenue For Each City


# creating View

-- 1 
create view city_revenue as 
SELECT 
t.month, t.city_id , c.city_name,
sum(t.fare_amount) as revenue
from 
fact_trip t join dim_city c 
on t.city_id= c.city_id
group by t.city_id , t.month

-- 2
create view city_rev_details as
select * ,
max(revenue) over (partition by city_id) as max_rev, 
sum(revenue) over (partition by city_id) as total_city_rev
from city_revenue

-- 3 
create view city_highest_rev_month as
select  
  distinct city_name , max_rev, 
  date_format(month,'%M') as highest_revenue_month,
  total_city_rev, 
  round( (max_rev /total_city_rev)*100,2) as revenue_contribution
from city_rev_details
where revenue = max_rev

-- city highest month revenue 
select 
  city_name , highest_revenue_month , 
  max_rev as revenue, 
  revenue_contribution  as percentage_contribution
from city_highest_rev_month


-- BR6            Repeat Passenger Rate Analysis

-- Metric 1: Monthly Repeat Passenger Rate

WITH MonthlyRate AS (
    SELECT 
        c.city_name,
        p.month,
        p.total_passengers,
        p.repeat_passengers,
        ROUND((p.repeat_passengers * 100.0) / p.total_passengers, 2) AS monthly_repeat_passenger_rate
    FROM 
        fact_passenger_summary p
    JOIN 
        dim_city c
    ON 
        p.city_id = c.city_id
),

-- Metric 2: City-wide Repeat Passenger Rate
CityWideRate AS (
    SELECT 
        c.city_name,
        SUM(p.total_passengers) AS total_passengers_citywide,
        SUM(p.repeat_passengers) AS repeat_passengers_citywide,
        ROUND((SUM(p.repeat_passengers) * 100.0) / SUM(p.total_passengers), 2) AS city_repeat_passenger_rate
    FROM 
        fact_passenger_summary p
    JOIN 
        dim_city c
    ON 
        p.city_id = c.city_id
    GROUP BY 
        c.city_name
)

-- Combine Results
SELECT 
    m.city_name,
    m.month,
    m.total_passengers,
    m.repeat_passengers,
    m.monthly_repeat_passenger_rate,
    c.city_repeat_passenger_rate
FROM 
    MonthlyRate m
JOIN 
    CityWideRate c
ON 
    m.city_name = c.city_name
ORDER BY 
    m.city_name, m.month;