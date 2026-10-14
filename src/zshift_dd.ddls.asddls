@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Shift Value Help'

@ObjectModel.resultSet.sizeCategory: #XS

define view entity ZSHIFT_DD
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE(
                   p_domain_name: 'ZDOM_SHIFT'
                 ) as DomainValue

    left outer join DDCDS_CUSTOMER_DOMAIN_VALUE_T(
                      p_domain_name: 'ZDOM_SHIFT'
                    ) as DomainText

      on  DomainText.domain_name    = DomainValue.domain_name
      and DomainText.value_position = DomainValue.value_position
      and DomainText.language       = $session.system_language

{
      @ObjectModel.text.element: [ 'ShiftText' ]
      @UI.textArrangement: #TEXT_ONLY

  key DomainValue.value_low as Shift,

      @Semantics.text: true
      DomainText.text        as ShiftText
}
