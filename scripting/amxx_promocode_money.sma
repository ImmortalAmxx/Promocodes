#include <amxmodx>
#include <api_promocode>
#include <reapi>

// Название промокода, который выдает деньги.
//
// The name of the promo code that gives away the money.
new const PROMONAME[] = "MONEY";

// Количество выдаваемых денег.
//
// The amount of money to be given out.
const MONEY = 16000;

public promocode_use_promo_post(UserId, szName[]) {
    if(equal(szName, PROMONAME))
        rg_add_account(UserId, MONEY, AS_SET);
}