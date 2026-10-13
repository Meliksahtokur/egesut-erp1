'use strict';
function sqlBlok(sql, ad) {
  const m = new RegExp('CREATE (?:OR REPLACE )?FUNCTION public\\.' + ad + '\\(').exec(sql);
  if (!m) throw new Error('tanım yok: ' + ad);
  const ac = sql.indexOf('AS $function$', m.index);
  const son = ac === -1 ? -1 : sql.indexOf('$function$;', ac + 13);
  if (son === -1) throw new Error('gövde kapanmadı: ' + ad);
  return sql.slice(m.index, son);
}
module.exports = { sqlBlok };
