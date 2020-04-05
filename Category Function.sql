--Category Function

use sakila
go

declare @Customer int = 130

;with CTE_RentedCatCount
as
(
select distinct
	C.category_id
	,count(*) over (partition by C.category_id) as Count
from dbo.rental as R
inner join dbo.inventory as I
on R.inventory_id = I.inventory_id
inner join dbo.film as F
on I.film_id = F.film_id
inner join dbo.film_category as FC
on I.film_id = FC.film_id
right join dbo.category as C
on FC.category_id = C.category_id
where customer_id = @customer
)
,CTE_AllCatCount
as
(
select
	C.category_id
	,name
	,cast(isnull(Count,0) as float) as Count
from CTE_RentedCatCount as CC
right join dbo.category as C
on  CC.category_id = C.category_id
)
,CTE_CatZ
as
(
select
	*
	,(Count - (avg(Count) over (partition by 1))) / (STDEV(Count) over (partition by 1)) as z
from CTE_AllCatCount
)

select
	*
	,case
		when z <= -0.8416 then 1
		when z <= -0.2533 then 2
		when z <= 0.2533 then 3
		when z <= 0.8416 then 4
		when z > 0.8416 then 5
	end as CatScore
from CTE_CatZ