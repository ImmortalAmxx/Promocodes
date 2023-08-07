#include <amxmodx>
#include <api_promocode>

// Момент создания промокода.
//
// Promo Code creation moment.
public promocode_add_promo(UserId, szName[], szDesc[], MaxUse) {
    client_print(0, print_chat, "Администратор %n добавил промокод %s", UserId, szName);
    client_print(0, print_chat, "Описание: %s | Максимум использований: %i", szDesc, MaxUse);
}

// Активация по флагу t.
//
// Activation by flag t.
public promocode_use_promo_pre(UserId) {
	if(~get_user_flags(UserId) & ADMIN_LEVEL_H)
		return PR_HANDLED;
		
	return PR_IGNORE;
}

// Полная активация промокода (тут по сути идёт выдача чего угодно).
//
// Full activation of the promo code (it basically gives out anything).
public promocode_use_promo_post(UserId, szName[], szDesc[], CanUse) {
    client_print(0, print_chat, "Игрок %n использовал промокод %s", UserId, szName);
    client_print(0, print_chat, "Описание: %s | Осталось использований: %i", szDesc, CanUse);
}