UPDATE systempreferences SET value = 1 WHERE variable = "ChargeFinesOnClosedDays";
UPDATE systempreferences SET value = "Usage" WHERE variable = "FacetOrder";
UPDATE systempreferences SET value = "never" WHERE variable = "AutoRenewalNotices";
UPDATE systempreferences SET value = 1 WHERE variable = "RecordStaffUserOnCheckout";

UPDATE systempreferences SET value = 1 WHERE variable = "MARCOverlayRules";
DELETE FROM systempreferences WHERE variable = "MARCMergeRules";

UPDATE systempreferences SET value = 1 WHERE variable = "enableSimpleMessaging";
DELETE FROM systempreferences WHERE variable = "enableSimpleOpacMessaging";

UPDATE systempreferences SET value = "Advance_Notice|Hold_Filled|Overdue1|Overdue2|Item_Due" WHERE variable = "whichActionsToTickUsingSimp
leMessaging";
DELETE FROM systempreferences WHERE variable = "whichactionstotickusingsimpleopacmessaging";

DELETE FROM systempreferences WHERE variable = "BypassOnSiteCheckoutConfirmaition"; -- Replaced by OnSiteCheckoutsForce = 1
UPDATE systempreferences SET value = 1 WHERE variable = "OnSiteCheckoutsForce";

UPDATE systempreferences SET value = -2 WHERE variable = "SkipHoldTrapOnNotForLoanValue";
UPDATE systempreferences SET value = 0 WHERE variable = "Pseudonymization";
