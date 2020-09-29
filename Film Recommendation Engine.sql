--Create a film recommendation engine for the Sakila Database

use sakila
go

--Search Function by Customer Name

create or alter function dbo.NameToID(@fname varchar(100),@lname varchar(100))
returns int
as
begin

declare @Customer int
return
(
	select 
		customer_id
	from dbo.customer
	where first_name like '%' + @fname + '%'
		and last_name like '%' + @lname + '%'
)

return @Customer
end
go

declare @CID int
set @CID = 
(
select dbo.fnNameToID('Mary','Sm')
)

--Category Function

drop table if exists dbo.CatScore

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
where customer_id = @CID
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
	category_id
	,case
		when z <= -0.8416 then 1
		when z <= -0.2533 then 2
		when z <= 0.2533 then 3
		when z <= 0.8416 then 4
		when z > 0.8416 then 5
	end as CatScore
into dbo.CatScore
from CTE_CatZ

--Actor Function

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
where customer_id = @CID
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

--Un-rented films

drop table if exists dbo.TotalScore

;with CTE_Unrented
as
(
select
	film_id
from dbo.film
where film_id not in
(
select
	film_id
from dbo.rental  as R
inner join dbo.inventory as I
on R.inventory_id = I.inventory_id
where customer_id = @CID
)
)

,CTE_AllScores
as
(
select distinct
	U.film_id
	,ApprovalScore
	,CatScore
	,avg(ActorScore) over (partition by U.film_id) as ActorScoreFilm
from CTE_Unrented as U
inner join dbo.ApprovalScore as A
on U.film_id = A.film_id
inner join dbo.film_category as FC
on U.film_id = FC.film_id
inner join dbo.CatScore as C
on FC.category_id = C.category_id
right join dbo.film_actor as FA
on FA.film_id = U.film_id
inner join dbo.ActorScore as AC
on FA.actor_id = AC.actor_id
where ApprovalScore is not null
)

,CTE_TotalScore
as
(
select
	*
	,ApprovalScore + CatScore + ActorScoreFilm as TotalScore
from CTE_AllScores
)

select top 10
	title
	,ApprovalScore
	,CatScore
	,ActorScoreFilm
	,TotalScore
into dbo.TotalScore
from CTE_TotalScore as T
inner join dbo.film as F
on T.film_id = F.film_id
order by TotalScore desc

select
	title
	,TotalScore
from dbo.TotalScore

/*

Potential Improvements:

-Pass the score table through a function to describe why each film was recommended: "Because you like Sci-Fi"/"Starring Fred Costner"/"Critically acclaimed"

*/