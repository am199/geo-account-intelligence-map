public with sharing class LeadAddressCheckController {
  public void ApexPractice(){
    sObject acc= new Account();
    Schema.describeSobjectResult dsr=Account.sObjectType.getDescribe();
    schema.describeFieldResult fsr= Schema.sObjectType.Account.Fields.name;
  }
}