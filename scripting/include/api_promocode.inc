#if defined _api_promocode_included
	#endinput
#endif
#define _api_promocode_included

/**
    Форвард вызывается в момент добавления промокода.

    UserId - Индекс игрока.
    szName - Название промокода.
    szDesc - Описание промокода.
    MaxUse - Количество использований.
*/
forward promocode_add_promo(UserId, szName[], szDesc[], MaxUse);

/**
    Форвард вызывается в момент использования промокода с возможностью блокировки.

    UserId - Индекс игрока.
    szName - Название промокода.
    szDesc - Описание промокода.
    CanUse - Количество использований.
	
	return PR_IGNORE - Игнорировать.
	return PR_HANDLED - Заблокировать.
*/
forward promocode_use_promo_pre(UserId, szName[], szDesc[], CanUse);

/**
    Форвард вызывается в момент использования промокода.

    UserId - Индекс игрока.
    szName - Название промокода.
    szDesc - Описание промокода.
    CanUse - Количество использований.
*/
forward promocode_use_promo_post(UserId, szName[], szDesc[], CanUse);

const PR_IGNORE = 0xA734;
const PR_HANDLED = 0xB371;