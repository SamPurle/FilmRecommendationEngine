--Approval Function

drop table if exists dbo.ApprovalScore

;with CTE_ApprovalStats
as
(
select
	film_id
	,approval_rating
	,avg(approval_rating) over (partition by 1) as Mean
from dbo.film
)

,CTE_ApprovalCleaned
as
(
select
	film_id
	,isnull(approval_rating,Mean) as ApprovalCleaned
from CTE_ApprovalStats
)

,CTE_ApprovalZ
as
(
select
	film_id
	,(ApprovalCleaned - (avg(ApprovalCleaned) over (partition by 1))) / (stdev(ApprovalCleaned) over (partition by 1)) as z
from CTE_ApprovalCleaned
)

select
	film_id
	,case
		when z <= -0.8416 then 1
		when z <= -0.2533 then 2
		when z <= 0.2533 then 3
		when z <= 0.8416 then 4
		when z > 0.8416 then 5
	end as ApprovalScore
into dbo.ApprovalScore
from CTE_ApprovalZ