SELECT*
FROM RaysPitching.Dbo.LastPitchRays

SELECT*
FROM RaysPitching.Dbo.RaysPitchingStats


--Question 1 AVG Pitches Per at Bat Analysis

--1a AVG Pitches Per At Bat (LastPitchRays)

SELECT AVG(1.00 * Pitch_number) AvgNumofPitchesPerAtBat
FROM RaysPitching.Dbo.LastPitchRays

--1b AVG Pitches Per At Bat Home Vs Away (LastPitchRays) -> Union

SELECT
	'Home' TypeofGame,
	AVG(1.00 * Pitch_number) AvgNumofPitchesPerAtBat
FROM RaysPitching.Dbo.LastPitchRays
Where home_team = 'TB'
UNION
SELECT
	'Away' TypeofGame,
	AVG(1.00 * Pitch_number) AvgNumofPitchesPerAtBat
FROM RaysPitching.Dbo.LastPitchRays
Where away_team = 'TB'

--1c AVG Pitches Per At Bat Lefty Vs Righty -> Case Statement

SELECT
	AVG(Case when batter_position = 'L' Then 1.00 * Pitch_number end) LeftyAtBats,
	AVG(Case when batter_position = 'R' Then 1.00 * Pitch_number end) RightyAtBats
FROM RaysPitching.Dbo.LastPitchRays

--1d AVG Pitches Per At Bat Lefty Vs Righty Pitcher | Each Away Team -> Partition By

SELECT DISTINCT
	home_team,
	Pitcher_position,
	AVG(1.00 * Pitch_number) OVER (Partition by home_team, Pitcher_position)
FROM RaysPitching.Dbo.LastPitchRays
Where away_team = 'TB'

--1e Top 3 Most Common Pitch for at bat 1 through 10, and total amounts (LastPitchRays)

with TotalPitchSequence as (
	SELECT DISTINCT
		Pitch_name,
		Pitch_number,
		count(pitch_name) OVER (Partition by Pitch_name, Pitch_number) PitchFrequency
	FROM RaysPitching.Dbo.LastPitchRays
	WHERE Pitch_number < 11
),
PitchFrequencyRankQuery as (
	SELECT
	Pitch_name,
	Pitch_number,
	PitchFrequency,
	rank() OVER (Partition by Pitch_number order by PitchFrequency desc) PitchFrequencyRanking
	FROM TotalPitchSequence
)
SELECT *
FROM PitchFrequencyRankQuery
WHERE PitchFrequencyRanking < 4

--1f AVG Pitches Per at Bat Per Pitcher with 20+ Innings | Order in descending (LastPitchRays + RaysPitchingStats)

SELECT 
	RPS.Name, 
	AVG(1.00 * Pitch_number) AVGPitches
FROM RaysPitching.Dbo.LastPitchRays LPR
JOIN RaysPitching.Dbo.RaysPitchingStats RPS ON RPS.pitcher_id = LPR.pitcher
WHERE IP >= 20
group by RPS.name
ORDER BY AVG(1.00 * Pitch_number) DESC

-- Question 2 Last Pitch Analysis

--2a Count of Last Pitches Thrown in Desc Order (LastPitchRays)

SELECT
	pitch_name,
	count (*) TimesThrown
FROM RaysPitching.Dbo.LastPitchRays
Group by pitch_name
order by count(*) DESC

--2b Count of the different last pitches Fastball or Offspeed (LastPitchRays)

SELECT
	sum(case when pitch_name in ('4-Seam Fastball', 'Cutter') then 1 else 0 end) Fastball,
	sum(case when pitch_name NOT in ('4-Seam Fastball', 'Cutter') then 1 else 0 end) Offspeed
FROM RaysPitching.Dbo.LastPitchRays

--2c Percentage of the different last pitches Fastball or Offspeed (LastPitchRays)

SELECT
	100 * sum(case when pitch_name in ('4-Seam Fastball', 'Cutter') then 1 else 0 end) / count(*) FastballPercent,
	100 * sum(case when pitch_name NOT in ('4-Seam Fastball', 'Cutter') then 1 else 0 end) /count(*) OffspeedPercent
FROM RaysPitching.Dbo.LastPitchRays

--2d Top 5 Most Common last pitch for a Relief Pitcher vs Starting Pitcher (LastPitchRays + RaysPitchingStats)

SELECT *
FROM (
	SELECT 
		a.Pos,
		a.pitch_name,
		a.timesthrown,
		RANK() OVER (Partition by a.pos Order by a.timesthrown desc) PitchRank
	FROM (

		SELECT
			RPS.Pos,
			LPR.pitch_name,
			count (*) TimesThrown
		FROM RaysPitching.Dbo.LastPitchRays LPR
		JOIN RaysPitching.Dbo.RaysPitchingStats RPS ON RPS.pitcher_id = LPR.pitcher
		group by RPS.Pos, LPR.pitch_name
	) a
)b
WHERE b.PitchRank < 6

-- Question 4 Homerun Analysis

--3a What pitches have given up the most HRs (LastPitchRays)

SELECT
	pitch_name,
	count (*) NumOfHRs
FROM RaysPitching.Dbo.LastPitchRays
WHERE events = 'home_run'
group by pitch_name
Order by NumOfHRs desc

--3b Show HRs given up by zone and pitch, show top 5 most common

SELECT Top 5
	pitch_name,
	zone,
	count (*) NumOfHRs
FROM RaysPitching.Dbo.LastPitchRays
WHERE events = 'home_run'
group by pitch_name, zone
order by NumOfHRs desc

--3c Show HRs for each count type -> Balls/Strikes + Type of Pitcher

SELECT
	LPR.balls,
	LPR.strikes,
	RPS.Pos,
	count (*) NumOfHRs
	FROM RaysPitching.Dbo.LastPitchRays LPR
	JOIN RaysPitching.Dbo.RaysPitchingStats RPS ON RPS.pitcher_id = LPR.pitcher
WHERE events = 'home_run'
group by LPR.balls, LPR.strikes, RPS.Pos
order by NumOfHRs desc

--3d Show each pitchers most common count to give up a HR (Min 30 IP)

with HRCountPitchers as (
	SELECT 
		RPS.Name,
		LPR.balls,
		LPR.strikes,
		count (*) NumOfHRs
	FROM RaysPitching.Dbo.LastPitchRays LPR
	JOIN RaysPitching.Dbo.RaysPitchingStats RPS ON RPS.pitcher_id = LPR.pitcher
	WHERE events = 'home_run' and IP >= 30
	group by RPS.name, LPR.balls, LPR.strikes
),
HRCountRanks as (
	SELECT
		HCP.name,
		HCP.balls,
		HCP.strikes,
		HCP.NumOfHRs,
		Rank () OVER (Partition by HCP.name order by HCP.NumofHRs desc) NumOfHRsRanking
	FROM HRCountPitchers HCP
)
SELECT
	ht.Name,
	ht.Balls,
	ht.strikes,
	ht.NumofHRs
FROM HRCountRanks ht
WHERE NumOfHRsRanking = 1

-- Question 4 Shane McClanahan

-- 4a Average release speed, spin rate, strikeouts, most popular zone ONLY using LastPitchRays

SELECT
	AVG(release_speed) AvgReleaseSpeed,
	AVG(release_spin_rate) AvgReleaseSpinRate,
	SUM(case when events = 'strikeout' then 1 else 0 end) strikeouts,
	MAX(zones.zone) as Zone
FROM RaysPitching.dbo.LastPitchRays LPR
join (
	SELECT Top 1 pitcher, zone, count(*) zonenum
	FROM RaysPitching.dbo.LastPitchRays LPR
	WHERE player_name = 'McClanahan, Shane'
	group by pitcher, zone
	order by count(*) desc

) zones on zones.pitcher = LPR.pitcher
WHERE player_name = 'McClanahan, Shane'

--4b Top pitches for each infield position where total positions are over 5, rank them

SELECT *
FROM (
	SELECT pitch_name, count(*) TimesHit, 'Third' Position
	FROM RaysPitching.dbo.LastPitchRays
	WHERE hit_location = 5 and player_name = 'McClanahan, Shane'
	GROUP BY pitch_name
	UNION
	SELECT pitch_name, count(*) TimesHit, 'Short' Position
	FROM RaysPitching.dbo.LastPitchRays
	WHERE hit_location = 6 and player_name = 'McClanahan, Shane'
	GROUP BY pitch_name
	UNION
	SELECT pitch_name, count(*) TimesHit, 'Second' Position
	FROM RaysPitching.dbo.LastPitchRays
	WHERE hit_location = 4 and player_name = 'McClanahan, Shane'
	GROUP BY pitch_name
	UNION
	SELECT pitch_name, count(*) TimesHit, 'First' Position
	FROM RaysPitching.dbo.LastPitchRays
	WHERE hit_location = 3 and player_name = 'McClanahan, Shane'
	GROUP BY pitch_name
) a
WHERE TimesHit > 4
ORDER BY TimesHit desc

--4c Show different balls and strikes as well as frequency when someone is on base

SELECT balls, strikes, count(*) Frequency
FROM RaysPitching.dbo.LastPitchRays
WHERE (on_3b is NOT NULL or on_2b is NOT NULL or on_1b is NOT NULL) and player_name = 'McClanahan, Shane'
GROUP BY balls, strikes
ORDER BY Frequency desc

--4d Which pitch causes the lowest launch speed?

SELECT TOP 1 pitch_name, avg(launch_speed * 1.00) AvgLaunchSpeed
FROM RaysPitching.dbo.LastPitchRays
WHERE player_name = 'McClanahan, Shane'
GROUP BY pitch_name
ORDER BY AvgLaunchSpeed asc
