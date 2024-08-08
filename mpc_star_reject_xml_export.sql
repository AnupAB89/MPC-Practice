/*******************************TEST****on Branch***************************************

	mpc_star_reject_xml_export

	Author: Andrew J. Sechrist
	Created: 2023-04-14

	Function returns XML export file for rejects from the starstaging
	table.

	2024-05-13 ajsechrist: Converted to straight query. Values are 
		returned to calling app for XML formatting.

**************************************************************************/
create or alter procedure [dbo].[mpc_star_reject_xml_export]

as

exec as caller

begin

select 
	ImportTicketNumber
	,CASE WHEN ISNULL(TRY_CAST(StarTicketNumber as int),0) between 1500000 and 1599999 THEN CAST(TRY_CAST(StarTicketNumber as int)+400000 as varchar(9)) ELSE StarTicketNumber END as StarTicketNumber
	,LeaseNumber
	,LocationName
	,CompanyNumber
	,isnull(CommonCarrierNumber,0) as CommonCarrierNumber
	,isnull(ShipperNumber,0) as ShipperNumber
	,CommodityName
	,MeasurementType
	,RunTicketType
	,isnull(OpenDateTime,convert(varchar(20),CreatedDate,127)) OpenDateTime
	,dbo.mpc_f_star_alter_remark(Remark) Remark
	,OpenGauger
	,DriverID
	,TruckID
	,TrailerID
	,ModifyUser
	,ModifyDateTime
	,MeterNumber
	,TankNumber
from StarStaging s 
where 
	MeasurementType in ('M','T')
	and Status = 'Rejected' 
	and ISNULL(RecordExported,'NO') <> 'YES'
	/*Filtering logic for PONumber*/
	and (CommonCarrierNumber in ('6010', '7878', '3408') or isnull(PONumber,') <> ' or SourceData not in ('PORTAL','TMW') )
	and s.OrderNumber > 1315780
end


