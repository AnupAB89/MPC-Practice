/***************************************************************************************

	mpc_manual_runtickets_from_TMW

	Author: George Varsamopoulos

	2023-08-23 HM52 - INC1794867 - Fixed MeterFactor to be read off of
		OFR.MeterFactor instead of hardcoding it to 1.0

	2024-05-16 ajsechrist: Added functional switch for new RevType field alignements.

***************************************************************************************/
create or alter procedure mpc_manual_runtickets_from_TMW
(
	@Exclude_Revtype1 varchar(max) = '''OH07'',''OH08''',
	@Exclude_Revtype2 varchar(max) = '''CADCRU'',''MARCRU''',
	@Exclude_ttsusers varchar(max) = '''SVC_TMW'',''TMW'',''TOTALMAIL'',''sql_tmail''',
	@Lookback_days varchar(max) = '30'
)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SELECT
		CAST('TMW' as [varchar](16)) as [SourceData]
		,CAST(OFR.ord_hdrnumber as [varchar] (20)) AS [DispatchID]
		,CAST('0' AS [decimal](11,0)) as [StopNumber]
		,CAST(GETDATE() AS [datetime]) as [CreatedDate]
		,COALESCE(RN_ENGAGE.ref_number,cast(OFR.ord_hdrnumber AS [varchar](24))) as [ImportTicketNumber]
		,cast(CASE WHEN OH.Ord_revtype4 = 'REJLD' THEN 'Rejected' ELSE 'Completed' end as [varchar](24)) as [Status]
		,CASE
			WHEN ISNULL(trim(sCMP.cmp_misc5),'') like '[0-9]%[0-9]' THEN ISNULL(trim(sCMP.cmp_misc5),'')
			WHEN ISNULL(trim(sCMP.cmp_misc1),'') like '[0-9]%[0-9]' THEN ISNULL(trim(sCMP.cmp_misc1),'')
			WHEN ISNULL(right(sCMP.cmp_id,len(sCMP.cmp_id)-1),'') like '[0-9]%[0-9]' THEN ISNULL(right(sCMP.cmp_id,len(sCMP.cmp_id)-1),'') ELSE 0
		END LeaseNumber
		,CAST(LEFT(ltrim(rtrim(dcompany.cmp_name)),64) as [varchar](64)) as [LocationName]
		,case
			when try_cast(LEFT(LTRIM(RTRIM(lf2.label_extrastring2)),4) as varchar(4)) like '[0-9]%' then cast(LEFT(LTRIM(RTRIM(lf2.label_extrastring2)),4) as varchar(4))
			when try_cast(LEFT(LTRIM(RTRIM(lf1.label_extrastring2)),4) as varchar(4)) like '[0-9]%' then cast(LEFT(LTRIM(RTRIM(lf1.label_extrastring2)),4) as varchar(4))
			else '0'
		end as [CompanyNumber]
       ,CAST(case
	   			when oh.ord_carrier <> 'UNKNOWN' then car.car_otherid
				else CASE
						WHEN tp.trc_fleet in ('TIOCRU','STACRU') THEN '6010'
						WHEN tp.trc_fleet in ('BLMCRU','PCSCRU','CRLCRU','MASCRU') THEN '7878'
						ELSE '3408' END
				end as [int]) as [CommonCarrierNumber]
		,case
		  	when try_cast(LEFT(LTRIM(RTRIM(lf2.label_extrastring1)),4) as varchar(4)) like '[0-9]%[0-9]' then cast(LEFT(LTRIM(RTRIM(lf2.label_extrastring1)),4) as varchar(4))
			when try_cast(LEFT(LTRIM(RTRIM(lf1.label_extrastring1)),4) as varchar(4)) like '[0-9]%[0-9]' then cast(LEFT(LTRIM(RTRIM(lf1.label_extrastring1)),4) as varchar(4))
			else '0'
		end as [ShipperNumber]
       ,CMD.Cmd_Name AS [CommodityName]
       ,CASE
			WHEN OH.ord_revtype4 = 'GARLD' or OFR.TicketType = 'GAUGE' THEN 'T'
			WHEN OFR.TicketType = 'METER' THEN 'M'
			else CASE WHEN ISNULL(OFR.ofr_topgaugemeasurement,0)>0 and ISNULL(OFR.ofr_topgaugemeasurement,0)>0 THEN 'T' ELSE 'M' END
       	END AS [MeasurementType]
		,CAST(CASE WHEN OH.ord_revtype1 like ('UT%') or left(OH.ord_revtype2,6) in ('ROSCRU','SLCCRU') THEN 'G' ELSE 'T' END as [varchar](4)) as [RunTicketType]
		,convert(varchar(19),OFR.inv_seal_offdate,127) AS [OpenDateTime]
		,convert(varchar(19),OFR.inv_Seal_OnDate,127) AS [CloseDateTime]
		,CAST(LEFT(COALESCE(concat(MPP.mpp_FirstName,' ',MPP.mpp_LastName),concat(lgh_carrier,' Driver'),'Unknown driver'),64) as varchar(64)) AS [OpenWitness]
		,CAST(LEFT(COALESCE(concat(MPP.mpp_FirstName,' ',MPP.mpp_LastName),concat(lgh_carrier,' Driver'),'Unknown driver'),64) as varchar(64)) AS [CloseWitness]
		,OFR.inv_gravity AS [ObservedGravity]
		,OFR.inv_observedtemperature AS [ObservedTemp]
		,'0.0' AS [APIGravity60]
		,inv_BSW AS [BSWPercent]
		,fd.fgt_volume AS [GrossVolume]
		,'0' AS [GSVolume]
		,'0' AS [NetVolume]
		,'0' AS [BSWVolume]
		,CASE
			WHEN OH.Ord_revtype4 = 'GARLD' THEN concat('Seal Off: ',left(ltrim(rtrim(inv_seal_off)),16),',Seal On: ',left(ltrim(rtrim(inv_seal_on)),16),' ',ISNULL(ofr.Comments,''))
			WHEN OFR.TicketType = 'METER' THEN concat('Seal Off: ',left(ltrim(rtrim(inv_seal_off)),16),',Seal On: ',left(ltrim(rtrim(inv_seal_on)),16),' ',ISNULL(ofr.Comments,''))
			WHEN OFR.TicketType = 'GAUGE' THEN ISNULL(ofr.Comments,'') ELSE ISNULL(ofr.Comments,'')
		END AS [Remark]
		,CAST(LEFT(COALESCE(concat(MPP.mpp_FirstName,' ',MPP.mpp_LastName),concat(lgh_carrier,' Driver'),'Unknown driver'),64) as varchar(64)) AS [OpenGauger]
		,CAST(LEFT(COALESCE(concat(MPP.mpp_FirstName,' ',MPP.mpp_LastName),concat(lgh_carrier,' Driver'),'Unknown driver'),64) as varchar(64)) AS [CloseGauger]
		,CAST(NULL as [decimal](6,4)) as [Sulfur]
		,Leg.lgh_driver1 AS [DriverID]
		,Leg.lgh_tractor AS [TruckID]
		,Leg.lgh_primary_trailer AS [TrailerID]
		,CAST('Y' as [varchar](4)) as [WayBill]
		,'TMWM'  AS [ModifyUser]
		,CAST(format(getdate(),'yyyy-MM-ddTHH:mm:ss') as [varchar](20)) as [ModifyDateTime]
		,ctd.TankTranslation AS [TankNumber]
		,CAST(concat(
					RIGHT('00'+CAST(CAST(FLOOR(OFR.ofr_topgaugemeasurement/12.0) as INT) as VARCHAR(10)),2),'-'
					,RIGHT('00'+CAST(CAST(FLOOR(OFR.ofr_topgaugemeasurement -12.0*CAST(FLOOR(OFR.ofr_topgaugemeasurement/12.0) as INT)) AS INT) as VARCHAR(10)),2),'-'
					,RIGHT('00'+cast(CAST(ROUND((CAST(OFR.ofr_topgaugemeasurement  as decimal(10,4))%1)/0.25 ,0) as INT) as varchar(10)),2),'/04'
					) as [varchar](16)) as [OpenGauge]
		,CAST(CASE WHEN CAST(ltrim(RTRIM(OFR.inv_temperature)) AS DECIMAL(10,2)) > 999.0 THEN 999.9 ELSE RTRIM(ISNULL(OFR.inv_temperature,'0')) END as [decimal](4,1)) as [OpenTemp]
		,CAST(left(ltrim(rtrim(inv_seal_off)),16) as [varchar](16)) as [OpenSealOff] --
		,CAST(NULL as [decimal](7,5)) as [OpenCTL] --
		,CAST(concat(
					RIGHT('00'+CAST(CAST(FLOOR(OFR.ofr_bottomgaugemeasurement /12.0) as INT) as VARCHAR(10)),2),'-'
					,RIGHT('00'+CAST(CAST(FLOOR(OFR.ofr_bottomgaugemeasurement -12.0*CAST(FLOOR(OFR.ofr_bottomgaugemeasurement /12.0) as INT)) AS INT) as VARCHAR(10)),2),'-'
					,RIGHT('00'+cast(CAST(ROUND((CAST(OFR.ofr_bottomgaugemeasurement  as decimal(10,4))%1)/0.25 ,0) as INT) as varchar(10)),2)+'/04'
					) as [varchar](16)) as [CloseGauge]
       ,CAST(CASE WHEN CAST(ltrim(RTRIM(OFR.ofr_bottomtemp)) AS DECIMAL(10,2)) > 999.0 THEN 999.9 ELSE RTRIM(ISNULL(OFR.ofr_bottomtemp,'0')) END as [decimal](4,1)) as [CloseTemp]
       ,CAST(left(ltrim(rtrim(inv_seal_on)),16) as [varchar](16)) as [CloseSealOn]
       ,CAST(NULL as [decimal](7,5)) as [CloseCTL] --
       ,CAST(concat(
					RIGHT('00'+CAST(CAST(FLOOR(OFR.ofr_bottomgaugemeasurement /12.0) as INT) as VARCHAR(10)),2),'-'
					,RIGHT('00'+CAST(CAST(FLOOR(OFR.ofr_bottomgaugemeasurement -12.0*CAST(FLOOR(OFR.ofr_bottomgaugemeasurement /12.0) as INT)) AS INT) as VARCHAR(10)),2),'-'
					,RIGHT('00'+cast(CAST(ROUND((CAST(OFR.ofr_bottomgaugemeasurement  as decimal(10,4))%1)/0.25 ,0) as INT) as varchar(10)),2)+'/04'
					) as [varchar](16)) as [SWOpenGauge]
       ,CAST(concat(
					RIGHT('00'+CAST(CAST(FLOOR(OFR.ofr_bottomgaugemeasurement /12.0) as INT) as VARCHAR(10)),2),'-'
					,RIGHT('00'+CAST(CAST(FLOOR(OFR.ofr_bottomgaugemeasurement -12.0*CAST(FLOOR(OFR.ofr_bottomgaugemeasurement /12.0) as INT)) AS INT) as VARCHAR(10)),2),'-'
					,RIGHT('00'+cast(CAST(ROUND((CAST(OFR.ofr_bottomgaugemeasurement  as decimal(10,4))%1)/0.25 ,0) as INT) as varchar(10)),2)+'/04'
					) as [varchar](16))[SWCloseGauge]
		,ctd.TankTranslation AS [MeterNumber]
		,ofr_meterstart AS [OpenReading]
		,ofr_meterend AS [CloseReading]
		,CAST('0.0' as [decimal](4,1)) as [AvgLinePressure]
		,AvgLineTemp AS [AvgLineTemp]
		,NULL AS [CPL]
		,CAST(0.000 as [decimal](7,5)) as [CTL] --
		,isnull(try_cast(ofr.MeterFactor as decimal(6,4)),1.0) AS [MeterFactor]
		,CAST(NULL as [varchar](20)) as [MeterProvingDate]
		,Convert(Time,PUstp.stp_departuredate- PUstp.stp_arrivaldate) as [LoadUnloadTime]
		,CAST(NULL as [time]) as [WaitingTime]
		,CAST(NULL as [char] (1)) as [H2S]
		,CAST('N' as [char](1)) as [Chainups]
		,CAST(NULL as [varchar](3)) as [RecordExported]
		,CAST(left(ltrim(rtrim(OFR.ord_hdrnumber)),24) as [varchar](24)) as [OrderNumber]
		,CAST(left(ltrim(rtrim(OFR.ord_hdrnumber)),24) as [varchar](24)) as [StarTicketNumber]
		,CAST(left(trim(OFR.refusalReason),6) as [varchar](6)) as [RejectReasonCode]
	FROM OilFieldReadings AS OFR WITH (NOLOCK)
	INNER JOIN dbo.orderheader AS OH WITH(NOLOCK) ON OFR.ord_hdrnumber = OH.ord_hdrnumber
	INNER JOIN dbo.company AS sCMP WITH(NOLOCK) ON OFR.cmp_id = sCMP.cmp_ID
	INNER JOIN dbo.company as dcompany WITH(NOLOCK) on dcompany.cmp_id = Oh.ord_consignee
	INNER JOIN dbo.stops as PUstp WITH(NOLOCK) on PUstp.ord_hdrnumber = OH.ord_hdrnumber and PUstp.stp_event = 'LLD' and PUstp.cmp_id = oh.ord_shipper
	INNER JOIN dbo.legheader as leg with (nolock) ON leg.lgh_number = PUstp.lgh_number
	INNER JOIN dbo.stops as Dstop WITH(NOLOCK) on dstop.ord_hdrnumber = oh.ord_hdrnumber and Dstop.stp_event = 'LUL' and Dstop.cmp_id = oh.ord_consignee
	LEFT JOIN dbo.manpowerprofile AS mpp WITH(NOLOCK) on mpp_id = lgh_driver1 and mpp_id <>'UNKNOWN'
	INNER JOIN dbo.commodity AS CMD on leg.cmd_code = cmd.cmd_code
	LEFT JOIN dbo.tractorprofile tp on tp.trc_number = leg.lgh_tractor
	LEFT JOIN dbo.carrier car on car.car_id = oh.ord_carrier
	left join dbo.freightdetail as fd WITH(NOLOCK) on fd.fgt_number = OFR.fgt_number
	outer apply (select top 1
				ffbbcc.fbc_id,ffbbcc.fbc_tank_nbr
			from dbo.freight_by_compartment ffbbcc with(nolock)
			where ffbbcc.stp_number = PUstp.stp_number) fbc
	INNER JOIN dbo.company_tankdetail as ctd with(nolock) on ctd.cmp_id = sCMP.cmp_id and ctd.cmp_tank_id = fbc.fbc_tank_nbr
	LEFT JOIN dbo.labelfile lf1 (nolock) on lf1.labeldefinition = 'RevType1' and lf1.abbr = oh.ord_revtype1
	LEFT JOIN dbo.labelfile lf2 (nolock) on lf2.labeldefinition = 'RevType2' and lf2.abbr = oh.ord_revtype2
	outer apply (select top 1
				ref_number
			from dbo.ReferenceNumber AS RN_ENGAGE WITH (NOLOCK)
			WHERE RN_ENGAGE.ord_hdrnumber = OFR.ord_hdrnumber AND Ref_Type = 'ENGAGE') RN_ENGAGE
	outer apply (select top 1
				ref_number
			from dbo.ReferenceNumber AS RN_DOPNTEMP WITH (NOLOCK)
			WHERE RN_DOPNTEMP.ord_hdrnumber = OFR.ord_hdrnumber AND Ref_Type = 'DOPTEM') RN_DOPNTEMP
	outer apply (select top 1
				ref_number
			from dbo.ReferenceNumber AS RN_DOPNMETR WITH (NOLOCK)
			WHERE RN_DOPNMETR.ord_hdrnumber = OFR.ord_hdrnumber AND Ref_Type = 'DOPNM') RN_DOPNMETR
	outer apply (select top 1
				ref_number
			from dbo.ReferenceNumber AS RN_DCLSMETR WITH (NOLOCK)
			WHERE RN_DCLSMETR.ord_hdrnumber = OFR.ord_hdrnumber AND Ref_Type = 'DOCLSM') RN_DCLSMETR
	outer apply (select top 1
				ref_number
			from dbo.ReferenceNumber AS RN_DDETRSN WITH (NOLOCK)
			WHERE RN_DDETRSN.ord_hdrnumber = OFR.ord_hdrnumber AND Ref_Type = 'DREASN') RN_DDETRSN
	WHERE
       1=1
		and LEFT(oh.ord_shipper,2) LIKE 'M[0-9]'
		AND OH.ord_hdrnumber > 1265900
		AND @Exclude_Revtype1 not like '%'''+OH.ord_revtype1+'''%'
		AND @Exclude_Revtype2 not like '%'''+OH.ord_revtype2+'''%'
		AND OH.last_updatedate > DATEADD(MONTH,-3,GETDATE())
		AND OH.ord_status = 'CMP'
		AND @Exclude_ttsusers not like '%'''+UPPER(OFR.CreatedBy)+'''%'
		AND OFR.TicketType IS NOT NULL
		AND OFR.cmp_id IS NOT NULL
		AND OFR.run_ticket IS NOT NULL
		AND (
				OH.ord_revtype4 = 'REJLD'
				OR (
					1=1
					and OFR.inv_gravity IS NOT NULL
					AND OFR.inv_observedtemperature IS NOT NULL
					AND OFR.inv_BSW IS NOT NULL
					AND OFR.inv_seal_Off IS NOT NULL
					AND OFR.inv_seal_On IS NOT NULL
					AND OFR.inv_seal_offdate IS NOT NULL
					AND OFR.inv_seal_ondate IS NOT NULL
					AND (
							(OFR.TicketType = 'GAUGE' AND OFR.ofr_bottomgaugemeasurement IS NOT NULL)
						OR (OFR.TicketType = 'METER' AND OFR.ofr_meterstart IS NOT NULL AND OFR.ofr_meterend IS NOT NULL)
						)
					)
			)
		and DATEDIFF(DAY,coalesce(OFR.UpdatedDateTime,OFR.CreatedDateTime),GETDATE()) <= @Lookback_days
;
END

