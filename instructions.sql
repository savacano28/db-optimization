--select count(*) from posts
--select count(*) from comments
--select * from user_sys_privs; 
--select * from dba_tab_privs
--select * from dba_role_privsv
----------------------------------
--explain plan set statement_id='q1' for 
--set autotrace on 
--create materialized view vq1
--build immediate
--refresh complete on demand enable query rewrite
--as
select 
  u.id,
  badgecount,
  questioncount,
  round(cast(badgecount as float)/questioncount, 2) as ratio
from users u
inner join (
 select userid, count(id) as badgecount
  from badges
  where upper(name) like '%popular question%'
  group by userid
) pop on u.id = pop.userid
inner join (
  select owneruserid, count(id) as questioncount
  from posts
  where posttypeid = 1
  group by owneruserid
) q on u.id = q.owneruserid
where badgecount >= 10
order by ratio desc
--select * from plan_table where statement_id='q1'
--set autot on exp
--set autotrace on stat
--select plan_table_output from table(dbms_xplan.display());
--create bitmap index idx_posts_type_id on posts(posttypeid)
--alter session set query_rewrite_integrity = trusted; 
--alter session set query_rewrite_enabled = true;
------------------------------------ok
--explain plan set statement_id='q2' for 
--set autotrace on 
select id,  
   (select count(*) from posts
        where
            posttypeid = 1 and
            lasteditoruserid = u.id and
            owneruserid != u.id ) questionedits,
    ( select count(*) from posts
        where
            posttypeid = 2 and
            lasteditoruserid = u.id and
            owneruserid != u.id) answeredits,
    (select count(*) from posts
        where
            lasteditoruserid = u.id and
            owneruserid != u.id) totaledits
 from users u
 order by totaledits desc
--select * from plan_table where statement_id='q2'
--set autot on exp
--set autotrace on stat
--create index idx_posts_last_editor on posts(lasteditoruserid)
--create index idx_posts_owner_user on posts(owneruserid)
--create index idx_posts_owner_last_user_type on posts(lasteditoruserid,owneruserid,posttypeid)
--------------------------------------ok
--explain plan set statement_id='q3' for 
--set autotrace on 
--create materialized view vq3
--build immediate
--refresh complete on demand enable query rewrite
--as
select u.id,
    round((cast(count(a.id) as float) / cast((select count(*) from posts p where p.owneruserid = u.id and posttypeid = 1) as float) * 100),2) as selfanswerpercentage
from posts q
  inner join posts a on q.acceptedanswerid = a.id
  inner join users u on u.id = q.owneruserid
where q.owneruserid = a.owneruserid
group by u.id, displayname
having count(a.id) > 1
order by selfanswerpercentage desc
--select * from plan_table where statement_id='q3'
--set autot on exp
--set autotrace on stat
--create index idx_posts_accept_answer on posts(acceptedanswerid)
-------------------------------------- ok
--explain plan set statement_id='q4' for
--set autotrace on 
--create materialized view vq4
--build immediate
--refresh complete on demand enable query rewrite
--as
select t.postid, t.upvotes, t.downvotes, p.body, p.score, p.owneruserid from (
select
    postid, 
    sum(case when votetypeid = 2 then 1 else 0 end) as upvotes, 
    sum(case when votetypeid = 3 then 1 else 0 end) as downvotes
from votes where votetypeid in (2,3)
group by postid
) t  inner join posts p on t.postid = p.id
where downvotes>(upvotes * 0.5)
order by upvotes desc
--select * from plan_table where statement_id='q4'
--set autot on exp
--set autotrace on stat
--create bitmap index idx_votes_type_id on votes(votetypeid)
--------------------------------------ok
--explain plan set statement_id='q5' for 
--set autotrace on 
--create materialized view vq5_d
--build immediate
--refresh complete on demand enable query rewrite
--as
select
 p.owneruserid,
 p.id,
 p.score
from posts p
inner join posts q on q.id = p.parentid
where p.posttypeid = 2 and p.score > 5
and q.score > 3 and q.answercount = 1
and q.acceptedanswerid = p.id
--select * from plan_table where statement_id='q5'
--set autot on exp
--set autotrace on stat
--create index idx_posts_score on posts(score)
--create index idx_posts_parent_id on posts(parentid)
--create index idx_posts_answer_count on posts(answercount)
--create index idx_posts_score_answer_count on posts(score,answercount) -- conditions where
--drop index idx_posts_score
--drop index idx_posts_answer_count
--------------------------------------ok
--explain plan set statement_id='q6' for
--set autotrace on 
--create materialized view vq6
--build immediate
--refresh complete on demand enable query rewrite
--as
select
   parentid,
   count(id)
from posts
where posttypeid = 2 and length(body) <= 1500
  and upper(body) like '%ja%'
group by parentid
having count(id) > 1
order by count(id) desc
--select * from plan_table where statement_id='q6'
--set autot on exp
--set autotrace on stat
--create index idx_posts_len_body on posts(length(body))
--create index idx_posts_body on posts(upper(body)) --not on datatype varray, nested table, lob, ref...
--------------------------------------
--explain plan set statement_id='q7' for
--set autotrace on 
--create materialized view vq7
--build immediate
--refresh complete on demand enable query rewrite
--as
select users.id,
    count(posts.id) as answers,
    cast(avg(cast(score as float)) as numeric(6,2)) as average_answer_scor
from
    posts
  inner join
    users on users.id = owneruserid
where 
    posttypeid = 2
group by
    users.id, displayname
having
    count(posts.id) > 10
order by
    average_answer_scor desc
    
--set autot on exp
------------------------------------- view exemples
create materialized view --vq0 as select count(*) from users
create materialized view --vq1 build immediate refresh complete on commit as select count(*) from comments
drop materialized view --view?
------------ create view logs : stage table
create materialized view log on --posts with rowid(answercount,score) including new values;
drop materialized view log on --posts
------------ show views and log views
select mview_name, refresh_mode, refresh_method, last_refresh_type, to_char(last_refresh_date, 'yyyy-mm-dd hh24:mi:ss') last_refresh_date from all_mviews
select * from user_mview_logs
------------ update view
exec dbms_mview.refresh('vq1')
exec dbms_mview.refresh('vq3')
exec dbms_mview.refresh('vq4')
exec dbms_mview.refresh('vq5_d')
exec dbms_mview.refresh('vq6')
exec dbms_mview.refresh('vq7')
------------ update posts score
update posts set score = score*1.5 where rownum = 200
update posts set answercount = answercount*10 where rownum = 200
