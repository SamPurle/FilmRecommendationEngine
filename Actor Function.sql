--Actor Function

declare @Customer int = 130

drop table if exists dbo.ActorScore

;with CTE_RentedActorCount
as
(
select
	actor_id
	,cast(count(*) as float) as Count
from dbo.rental as R
inner join dbo.inventory as I
on R.inventory_id = I.inventory_id
inner join dbo.film as F
on I.film_id = F.film_id
inner join dbo.film_actor as FA
on F.film_id = FA.film_id
where customer_id = @Customer
group by customer_id, actor_id
)

,CTE_TotalActorCount
as
(
select
	A.actor_id
	,isnull(Count,0) as Count
from CTE_RentedActorCount as R
right join dbo.actor as A
on R.actor_id = A.actor_id
)

,CTE_ActorZ
as
(
select
	*
	,(Count - (avg(Count) over (partition by 1))) / (stdev(Count) over (partition by 1)) as z
from CTE_TotalActorCount
)

select
	actor_id
	,case
		when z <= -0.8416 then 1
		when z <= -0.2533 then 2
		when z <= 0.2533 then 3
		when z <= 0.8416 then 4
		when z > 0.8416 then 5
	end as ActorScore
into dbo.ActorScore
from CTE_ActorZ