USE WideWorldImporters;
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE tables.name = 'Dim_Date')
BEGIN
	CREATE TABLE dbo.Dim_Date (
		Calendar_Date DATE NOT NULL CONSTRAINT PK_Dim_Date PRIMARY KEY CLUSTERED,
		Calendar_Date_String VARCHAR(10) NOT NULL,
		Calendar_Month TINYINT NOT NULL,
		Calendar_Day TINYINT NOT NULL,
		Calendar_Year SMALLINT NOT NULL,
		Calendar_Quarter TINYINT NOT NULL,
		Day_Name VARCHAR(9) NOT NULL,
		Day_of_Week TINYINT NOT NULL,
		Day_of_Week_in_Month TINYINT NOT NULL,
		Day_of_Week_in_Year TINYINT NOT NULL,
		Day_of_Week_in_Quarter TINYINT NOT NULL,
		Day_of_Quarter TINYINT NOT NULL,
		Day_of_Year SMALLINT NOT NULL,
		Week_of_Month TINYINT NOT NULL,
		Week_of_Quarter TINYINT NOT NULL,
		Week_of_Year TINYINT NOT NULL,
		Month_Name VARCHAR(9) NOT NULL,
		First_Date_of_Week DATE NOT NULL,
		Last_Date_of_Week DATE NOT NULL,
		First_Date_of_Month DATE NOT NULL,
		Last_Date_of_Month DATE NOT NULL,
		First_Date_of_Quarter DATE NOT NULL,
		Last_Date_of_Quarter DATE NOT NULL,
		First_Date_of_Year DATE NOT NULL,
		Last_Date_of_Year DATE NOT NULL,
		Is_Holiday BIT NOT NULL,
		Holiday_Name VARCHAR(50) NULL,
		Is_Weekday BIT NOT NULL,
		Is_Business_Day BIT NOT NULL,
		Previous_Business_Day DATE NULL,
		Next_Business_Day DATE NULL,
		Is_Leap_Year BIT NOT NULL,
		Days_in_Month TINYINT NOT NULL)
	WITH (DATA_COMPRESSION = PAGE);
END
GO

CREATE OR ALTER PROCEDURE dbo.populate_dim_date
	@Start_Date DATE, -- Start of date range to process
	@End_Date DATE -- End of date range to process
AS
BEGIN
	SET NOCOUNT ON;
	
	IF @Start_Date IS NULL OR @End_Date IS NULL
	BEGIN
		SELECT 'Start and end dates MUST be provided in order for this stored procedure to work.';
		RETURN;
	END

	IF @Start_Date > @End_Date
	BEGIN
		SELECT 'Start date must be less than or equal to the end date.';
		RETURN;
	END

	-- Remove all old data for the date range provided.
	DELETE FROM dbo.Dim_Date
	WHERE Dim_Date.Calendar_Date BETWEEN @Start_Date AND @End_Date;
	-- These variables dirrectly correspond to columns in Dim_Date
	DECLARE @Date_Counter DATE = @Start_Date;
	DECLARE @Calendar_Date_String VARCHAR(10);
	DECLARE @Calendar_Month TINYINT;
	DECLARE @Calendar_Day TINYINT;
	DECLARE @Calendar_Year SMALLINT;
	DECLARE @Calendar_Quarter TINYINT;
	DECLARE @Day_Name VARCHAR(9);
	DECLARE @Day_of_Week TINYINT;
	DECLARE @Day_of_Week_in_Month TINYINT;
	DECLARE @Day_of_Week_in_Year TINYINT;
	DECLARE @Day_of_Week_in_Quarter TINYINT;
	DECLARE @Day_of_Quarter TINYINT;
	DECLARE @Day_of_Year SMALLINT;
	DECLARE @Week_of_Month TINYINT;
	DECLARE @Week_of_Quarter TINYINT;
	DECLARE @Week_of_Year TINYINT;
	DECLARE @Month_Name VARCHAR(9);
	DECLARE @First_Date_of_Week DATE;
	DECLARE @Last_Date_of_Week DATE;
	DECLARE @First_Date_of_Month DATE;
	DECLARE @Last_Date_of_Month DATE;
	DECLARE @First_Date_of_Quarter DATE;
	DECLARE @Last_Date_of_Quarter DATE;
	DECLARE @First_Date_of_Year DATE;
	DECLARE @Last_Date_of_Year DATE;
	DECLARE @Is_Holiday BIT;
	DECLARE @Holiday_Name VARCHAR(50);
	DECLARE @Is_Weekday BIT;
	DECLARE @Is_Business_Day BIT;
	DECLARE @Is_Leap_Year BIT;
	DECLARE @Days_in_Month TINYINT;

	-- These variables are used internally within this proc for various calculations
	DECLARE @First_Date_of_Next_Year DATE;
	DECLARE @First_Date_of_Last_Year DATE;

	WHILE @Date_Counter <= @End_Date
	BEGIN
		SELECT @Calendar_Month = DATEPART(MONTH, @Date_Counter);
		SELECT @Calendar_Day = DATEPART(DAY, @Date_Counter);
		SELECT @Calendar_Year = DATEPART(YEAR, @Date_Counter);
		SELECT @Calendar_Quarter = DATEPART(QUARTER, @Date_Counter);
		SELECT @Calendar_Date_String = CAST(@Calendar_Month AS VARCHAR(10)) + '/' + CAST(@Calendar_Day AS VARCHAR(10)) + '/' + CAST(@Calendar_Year AS VARCHAR(10));
		SELECT @Day_of_Week = DATEPART(WEEKDAY, @Date_Counter);
		SELECT @Is_Business_Day = CASE
									WHEN @Day_of_Week IN (1, 7) THEN 0
									ELSE 1
								  END;
		SELECT @Day_Name = CASE @Day_of_Week
								WHEN 1 THEN 'Sunday'
								WHEN 2 THEN 'Monday'
								WHEN 3 THEN 'Tuesday'
								WHEN 4 THEN 'Wednesday'
								WHEN 5 THEN 'Thursday'
								WHEN 6 THEN 'Friday'
								WHEN 7 THEN 'Saturday'
							END;
		SELECT @Day_of_Quarter = DATEDIFF(DAY, DATEADD(QUARTER, DATEDIFF(QUARTER, 0 , @Date_Counter), 0), @Date_Counter) + 1;
		SELECT @Day_of_Year = DATEPART(DAYOFYEAR, @Date_Counter);
		SELECT @Week_of_Month = DATEDIFF(WEEK, DATEADD(WEEK, DATEDIFF(WEEK, 0, DATEADD(MONTH, DATEDIFF(MONTH, 0, @Date_Counter), 0)), 0), @Date_Counter ) + 1;
		SELECT @Week_of_Quarter = DATEDIFF(DAY, DATEADD(QUARTER, DATEDIFF(QUARTER, 0, @Date_Counter), 0), @Date_Counter)/7 + 1;
		SELECT @Week_of_Year = DATEPART(WEEK, @Date_Counter);
		SELECT @Month_Name = CASE @Calendar_Month
								WHEN 1 THEN 'January'
								WHEN 2 THEN 'February'
								WHEN 3 THEN 'March'
								WHEN 4 THEN 'April'
								WHEN 5 THEN 'May'
								WHEN 6 THEN 'June'
								WHEN 7 THEN 'July'
								WHEN 8 THEN 'August'
								WHEN 9 THEN 'September'
								WHEN 10 THEN 'October'
								WHEN 11 THEN 'November'
								WHEN 12 THEN 'December'
							END;

		SELECT @First_Date_of_Week = DATEADD(DAY, -1 * @Day_of_Week + 1, @Date_Counter);
		SELECT @Last_Date_of_Week = DATEADD(DAY, 1 * (7 - @Day_of_Week), @Date_Counter);
		SELECT @First_Date_of_Month = DATEADD(DAY, -1 * DATEPART(DAY, @Date_Counter) + 1, @Date_Counter);
		SELECT @First_Date_of_Quarter = DATEADD(QUARTER, DATEDIFF(QUARTER, 0, @Date_Counter), 0);
		SELECT @Last_Date_of_Quarter = DATEADD (DAY, -1, DATEADD(QUARTER, DATEDIFF(QUARTER, 0, @Date_Counter) + 1, 0));
		SELECT @First_Date_of_Year = DATEADD(YEAR, DATEDIFF(YEAR, 0, @Date_Counter), 0);
		SELECT @Last_Date_of_Year = DATEADD(DAY, -1, DATEADD(YEAR, DATEDIFF(YEAR, 0, @Date_Counter) + 1, 0));
		SELECT @Is_Weekday = CASE
								WHEN @Day_of_Week IN (1, 7)
									THEN 0
								ELSE 1
							 END;
		SELECT @Day_of_Week_in_Month = (@Calendar_Day + 6) / 7;
		SELECT @Day_of_Week_in_Year = (@Day_of_Year + 6) / 7;
		SELECT @Day_of_Week_in_Quarter = (@Day_of_Quarter + 6) / 7;
		SELECT @Is_Leap_Year = CASE
									WHEN @Calendar_Year % 4 <> 0 THEN 0
									WHEN @Calendar_Year % 100 <> 0 THEN 1
									WHEN @Calendar_Year % 400 <> 0 THEN 0
									ELSE 1
							   END;
		SELECT @First_Date_of_Next_Year = DATEADD(YEAR, DATEDIFF(YEAR, 0, DATEADD(YEAR, 1, @Date_Counter)), 0);
		SELECT @First_Date_of_Last_Year = DATEADD(YEAR, DATEDIFF(YEAR, 0, DATEADD(YEAR, -1, @Date_Counter)), 0);

		SELECT @Days_in_Month = CASE
									WHEN @Calendar_Month IN (4, 6, 9, 11) THEN 30
									WHEN @Calendar_Month IN (1, 3, 5, 7, 8, 10, 12) THEN 31
									WHEN @Calendar_Month = 2 AND @Is_Leap_Year = 1 THEN 29
									ELSE 28
								END;

		SELECT @Last_Date_of_Month = DATEADD(DAY, @Days_in_Month - 1, @First_Date_of_Month);
								
		INSERT INTO dbo.Dim_Date
			(Calendar_Date, Calendar_Date_String, Calendar_Month, Calendar_Day, Calendar_Year, Calendar_Quarter, Day_Name, Day_of_Week, Day_of_Week_in_Month,
				Day_of_Week_in_Year, Day_of_Week_in_Quarter, Day_of_Quarter, Day_of_Year, Week_of_Month, Week_of_Quarter, Week_of_Year, Month_Name,
				First_Date_of_Week, Last_Date_of_Week, First_Date_of_Month, Last_Date_of_Month, First_Date_of_Quarter, Last_Date_of_Quarter, First_Date_of_Year,
				Last_Date_of_Year, Is_Holiday, Holiday_Name, Is_Weekday, Is_Business_Day, Previous_Business_Day, Next_Business_Day, Is_Leap_Year, Days_in_Month)
		SELECT
			@Date_Counter AS Calendar_Date,
			@Calendar_Date_String AS Calendar_Date_String,
			@Calendar_Month AS Calendar_Month,
			@Calendar_Day AS Calendar_Day,
			@Calendar_Year AS Calendar_Year,
			@Calendar_Quarter AS Calendar_Quarter,
			@Day_Name AS Day_Name,
			@Day_of_Week AS Day_of_Week,
			@Day_of_Week_in_Month AS Day_of_Week_in_Month,
			@Day_of_Week_in_Year AS Day_of_Week_in_Year,
			@Day_of_Week_in_Quarter AS Day_of_Week_in_Quarter,
			@Day_of_Quarter AS Day_of_Quarter,
			@Day_of_Year AS Day_of_Year,
			@Week_of_Month AS Week_of_Month,
			@Week_of_Quarter AS Week_of_Quarter,
			@Week_of_Year AS Week_of_Year,
			@Month_Name AS Month_Name,
			@First_Date_of_Week AS First_Date_of_Week,
			@Last_Date_of_Week AS Last_Date_of_Week,
			@First_Date_of_Month AS First_Date_of_Month,
			@Last_Date_of_Month AS Last_Date_of_Month,
			@First_Date_of_Quarter AS First_Date_of_Quarter,
			@Last_Date_of_Quarter AS Last_Date_of_Quarter,
			@First_Date_of_Year AS First_Date_of_Year,
			@Last_Date_of_Year AS Last_Date_of_Year,
			0 AS Is_Holiday,
			NULL AS Holiday_Name,
			@Is_Weekday AS Is_Weekday,
			@Is_Business_Day AS Is_Business_Day, -- Will be populated with weekends to start.
			NULL AS Previous_Business_Day,
			NULL AS Next_Business_Day,
			@Is_Leap_Year AS Is_Leap_Year,
			@Days_in_Month AS Days_in_Month;

		SELECT @Date_Counter = DATEADD(DAY, 1, @Date_Counter);
	END

	-- Holiday Calculations, which are based on CommerceHub holidays.  Is_Business_Day is determined based on Federal holidays only.

	-- New Year's Day: 1st of January
	UPDATE Dim_date
		SET Is_Holiday = 1,
			Holiday_Name = 'New Year''s Day',
			Is_Business_Day = 0
	FROM dbo.Dim_date
	WHERE Dim_Date.Calendar_Month = 1
	AND Dim_Date.Calendar_Day = 1
	AND Dim_date.Calendar_Date BETWEEN @Start_Date AND @End_Date;

	-- Martin Luther King, Jr. Day: 3rd Monday in January, beginning in 1983
	UPDATE Dim_date
		SET Is_Holiday = 1,
			Holiday_Name = 'Martin Luther King, Jr. Day',
			Is_Business_Day = 0
	FROM dbo.Dim_date
	WHERE Dim_Date.Calendar_Month = 1
	AND Dim_Date.Day_of_Week = 2
	AND Dim_Date.Day_of_Week_in_Month = 3
	AND Dim_date.Calendar_Year >= 1983
	AND Dim_date.Calendar_Date BETWEEN @Start_Date AND @End_Date;

	-- President's Day: 3rd Monday in February
	UPDATE Dim_date
		SET Is_Holiday = 1,
			Holiday_Name = 'President''s Day',
			Is_Business_Day = 0
	FROM dbo.Dim_date
	WHERE Dim_Date.Calendar_Month = 2
	AND Dim_Date.Day_of_Week = 2
	AND Dim_Date.Day_of_Week_in_Month = 3
	AND Dim_date.Calendar_Date BETWEEN @Start_Date AND @End_Date;

	-- Valentine's Day: 14th of February
	UPDATE Dim_date
		SET Is_Holiday = 1,
			Holiday_Name = 'Valentine''s Day'
	FROM dbo.Dim_date
	WHERE Dim_Date.Calendar_Month = 2
	AND Dim_Date.Calendar_Day = 14
	AND Dim_date.Calendar_Date BETWEEN @Start_Date AND @End_Date;

	-- Saint Patrick's Day: 17th of March
	UPDATE Dim_date
		SET Is_Holiday = 1,
			Holiday_Name = 'Saint Patrick''s Day'
	FROM dbo.Dim_date
	WHERE Dim_Date.Calendar_Month = 3
	AND Dim_Date.Calendar_Day = 17
	AND Dim_date.Calendar_Date BETWEEN @Start_Date AND @End_Date;

	-- Mother's Day: 2nd Sunday in May
		UPDATE Dim_date
		SET Is_Holiday = 1,
			Holiday_Name = 'Mother''s Day'
	FROM dbo.Dim_date
	WHERE Dim_Date.Calendar_Month = 5
	AND Dim_Date.Day_of_Week = 1
	AND Dim_Date.Day_of_Week_in_Month = 2
	AND Dim_date.Calendar_Date BETWEEN @Start_Date AND @End_Date;

	-- Memorial Day: Last Monday in May
	UPDATE Dim_date
		SET Is_Holiday = 1,
			Holiday_Name = 'Memorial Day',
			Is_Business_Day = 0
	FROM dbo.Dim_date
	WHERE Dim_Date.Calendar_Month = 5
	AND Dim_Date.Day_of_Week = 2
	AND Dim_Date.Day_of_Week_in_Month = (SELECT MAX(Dim_Date_Memorial_Day_Check.Day_of_Week_in_Month) FROM dbo.Dim_Date Dim_Date_Memorial_Day_Check WHERE Dim_Date_Memorial_Day_Check.Calendar_Month = Dim_Date.Calendar_Month
																									  AND Dim_Date_Memorial_Day_Check.Day_of_Week = Dim_Date.Day_of_Week
																									  AND Dim_Date_Memorial_Day_Check.Calendar_Year = Dim_Date.Calendar_Year)
	AND Dim_date.Calendar_Date BETWEEN @Start_Date AND @End_Date;

	-- Father's Day: 3rd Sunday in June
		UPDATE Dim_date
		SET Is_Holiday = 1,
			Holiday_Name = 'Father''s Day'
	FROM dbo.Dim_date
	WHERE Dim_Date.Calendar_Month = 6
	AND Dim_Date.Day_of_Week = 1
	AND Dim_Date.Day_of_Week_in_Month = 3
	AND Dim_date.Calendar_Date BETWEEN @Start_Date AND @End_Date;

	-- Independence Day (USA): 4th of July
	UPDATE Dim_date
		SET Is_Holiday = 1,
			Holiday_Name = 'Independence Day (USA)',
			Is_Business_Day = 0
	FROM dbo.Dim_date
	WHERE Dim_Date.Calendar_Month = 7
	AND Dim_Date.Calendar_Day = 4
	AND Dim_date.Calendar_Date BETWEEN @Start_Date AND @End_Date;

	-- Labor Day: 1st Monday in September
	UPDATE Dim_date
		SET Is_Holiday = 1,
			Holiday_Name = 'Labor Day',
			Is_Business_Day = 0
	FROM dbo.Dim_date
	WHERE Dim_Date.Calendar_Month = 9
	AND Dim_Date.Day_of_Week = 2
	AND Dim_Date.Day_of_Week_in_Month = 1
	AND Dim_date.Calendar_Date BETWEEN @Start_Date AND @End_Date;

	-- Columbus Day: 2nd Monday in October
	UPDATE Dim_date
		SET Is_Holiday = 1,
			Holiday_Name = 'Columbus Day',
			Is_Business_Day = 0
	FROM dbo.Dim_date
	WHERE Dim_Date.Calendar_Month = 10
	AND Dim_Date.Day_of_Week = 2
	AND Dim_Date.Day_of_Week_in_Month = 2
	AND Dim_date.Calendar_Date BETWEEN @Start_Date AND @End_Date;

	-- Halloween: 31st of October
	UPDATE Dim_date
		SET Is_Holiday = 1,
			Holiday_Name = 'Halloween'
	FROM dbo.Dim_date
	WHERE Dim_Date.Calendar_Month = 10
	AND Dim_Date.Calendar_Day = 31
	AND Dim_date.Calendar_Date BETWEEN @Start_Date AND @End_Date;

	-- Veteran's Day: 11th of November
	UPDATE Dim_date
		SET Is_Holiday = 1,
			Holiday_Name = 'Veteran''s Day',
			Is_Business_Day = 0
	FROM dbo.Dim_date
	WHERE Dim_Date.Calendar_Month = 11
	AND Dim_Date.Calendar_Day = 11
	AND Dim_date.Calendar_Date BETWEEN @Start_Date AND @End_Date;

	-- Thanksgiving: 4th Thursday in November
	UPDATE Dim_date
		SET Is_Holiday = 1,
			Holiday_Name = 'Thanksgiving',
			Is_Business_Day = 0
	FROM dbo.Dim_date
	WHERE Dim_Date.Calendar_Month = 11
	AND Dim_Date.Day_of_Week = 5
	AND Dim_Date.Day_of_Week_in_Month = 4
	AND Dim_date.Calendar_Date BETWEEN @Start_Date AND @End_Date;

	-- Election Day (USA): 1st Tuesday after November 1st, only in even-numbered years.  Always in the range of November 2-8.
	UPDATE Dim_date
		SET Is_Holiday = 1,
			Holiday_Name = 'Election Day (USA)'
	FROM dbo.Dim_date
	WHERE Dim_Date.Calendar_Month = 11
	AND Dim_Date.Day_of_Week = 3
	AND Dim_Date.Calendar_Day BETWEEN 2 AND 8
	AND Dim_date.Calendar_Date BETWEEN @Start_Date AND @End_Date;

	-- Christmas: 25th of December
	UPDATE Dim_date
		SET Is_Holiday = 1,
			Holiday_Name = 'Christmas',
			Is_Business_Day = 0
	FROM dbo.Dim_date
	WHERE Dim_Date.Calendar_Month = 12
	AND Dim_Date.Calendar_Day = 25
	AND Dim_date.Calendar_Date BETWEEN @Start_Date AND @End_Date;

	-- Determine Easter for each year in the time frame provided and update Dim_Date with the results
	DECLARE @start_year SMALLINT = DATEPART(YEAR, @Start_Date);
	DECLARE @end_year SMALLINT = DATEPART(YEAR, @End_Date);
	DECLARE @current_year SMALLINT = @start_year;
	DECLARE @easter DATE;
	DECLARE @a TINYINT;
	DECLARE @b TINYINT;
	DECLARE @c TINYINT;
	DECLARE @H1 SMALLINT;
	DECLARE @H2 SMALLINT;
	DECLARE @M TINYINT;
	DECLARE @N TINYINT;
	DECLARE @d TINYINT;
	DECLARE @e TINYINT;
	DECLARE @o TINYINT;
	WHILE @current_year <= @end_year
	BEGIN
		-- Calculate Easter using the Gaussian algorithm
		SELECT @a = @current_year % 19;
		SELECT @b = @current_year % 4;
		SELECT @c = @current_year % 7;
		SELECT @H1 = @current_year / 100;
		SELECT @H2 = @current_year / 400;
		SELECT @N = 4 + @H1 - @H2;
		SELECT @M = 15 + @H1 - @H2 - ((8 * @H1 + 13) /25);
		SELECT @d = (19 * @a + @M) % 30;
		SELECT @e = (2 * @b + 4 * @c + 6 * @d + @N) % 7;
		SELECT @o = 22 + @d + @e;
		-- Exception handling
		IF @o = 57
		BEGIN
			SELECT @o = 50;
		END
		IF (@d = 28) AND (@e = 6) AND (@a > 10)
		BEGIN
			SELECT @o = 49;
		END

		SELECT @easter = DATEADD(DAY ,@o - 1 ,CONVERT(DATE ,CONVERT(CHAR(4), @current_year) + '0301', 112));

		UPDATE Dim_Date
			SET Is_Holiday = 1,
				Holiday_Name = 'Easter'
		FROM dbo.Dim_Date
		WHERE Dim_Date.Calendar_Date = @easter;

		SELECT @current_year = @current_year + 1;
	END;

	-- Merge weekday and holiday data into our data set to determine business days over the time span specified in the parameters.
	-- Previous Business Day
	WITH CTE_Business_Days AS (
		SELECT
			Business_Days.Calendar_Date
		FROM dbo.Dim_Date Business_Days
		WHERE Business_Days.Is_Business_Day = 1
	)
	UPDATE Dim_Date_Current
		SET Previous_Business_Day = CTE_Business_Days.Calendar_Date
	FROM dbo.Dim_Date Dim_Date_Current
	INNER JOIN CTE_Business_Days
	ON CTE_Business_Days.Calendar_Date = (SELECT MAX(Previous_Business_Day.Calendar_Date) FROM CTE_Business_Days Previous_Business_Day
										  WHERE Previous_Business_Day.Calendar_Date < Dim_Date_Current.Calendar_Date)
	WHERE Dim_Date_Current.Calendar_Date BETWEEN @Start_Date AND @End_Date;

	-- Next Business Day
	WITH CTE_Business_Days AS (
		SELECT
			Business_Days.Calendar_Date
		FROM dbo.Dim_Date Business_Days
		WHERE Business_Days.Is_Business_Day = 1
	)
	UPDATE Dim_Date_Current
		SET Next_Business_Day = CTE_Business_Days.Calendar_Date
	FROM dbo.Dim_Date Dim_Date_Current
	INNER JOIN CTE_Business_Days
	ON CTE_Business_Days.Calendar_Date = (SELECT MIN(Next_Business_Day.Calendar_Date) FROM CTE_Business_Days Next_Business_Day
										  WHERE Next_Business_Day.Calendar_Date > Dim_Date_Current.Calendar_Date)
	WHERE Dim_Date_Current.Calendar_Date BETWEEN @Start_Date AND @End_Date;
END
GO

EXEC dbo.populate_dim_date
	@Start_Date = '1/1/1980',
	@End_Date = '1/1/2100';
GO
