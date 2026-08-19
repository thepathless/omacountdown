// Model.js - Core calendar math, unit breakdown, formatters, and presets for OmaCountdown
.pragma library

var MONTH_NAMES = {
  "jan": 0, "january": 0,
  "feb": 1, "february": 1,
  "mar": 2, "march": 2,
  "apr": 3, "april": 3,
  "may": 4,
  "jun": 5, "june": 5,
  "jul": 6, "july": 6,
  "aug": 7, "august": 7,
  "sep": 8, "sept": 8, "september": 8,
  "oct": 9, "october": 9,
  "nov": 10, "november": 10,
  "dec": 11, "december": 11
};

var SHORT_MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

/**
 * Ensures countdowns array exists in settings with valid schema.
 * Migrates legacy single-event properties if countdowns array is empty.
 */
function ensureCountdowns(settings) {
  if (!settings) {
    return [{
      id: "evt_default",
      title: "Event",
      targetDate: "",
      startDate: new Date().toISOString(),
      iconStyle: "medical",
      customEmoji: "\uf0f1"
    }];
  }

  if (Array.isArray(settings.countdowns) && settings.countdowns.length > 0) {
    return settings.countdowns;
  }

  return [{
    id: "evt_1",
    title: (settings && settings.targetLabel !== undefined) ? settings.targetLabel : "Event",
    targetDate: settings.targetDate || "",
    startDate: settings.startDate || new Date().toISOString(),
    iconStyle: settings.iconStyle || "medical",
    customEmoji: settings.customEmoji || "\uf0f1"
  }];
}

/**
 * Returns the currently active event object from settings.
 */
function getActiveEvent(settings) {
  var list = ensureCountdowns(settings);
  var idx = (settings && typeof settings.activeIndex === "number") ? settings.activeIndex : 0;
  if (idx < 0 || idx >= list.length) idx = 0;
  return list[idx] || list[0];
}

/**
 * Returns the safe active index from settings.
 */
function getActiveIndex(settings) {
  var list = ensureCountdowns(settings);
  var idx = (settings && typeof settings.activeIndex === "number") ? settings.activeIndex : 0;
  if (idx < 0 || idx >= list.length) idx = 0;
  return idx;
}

/**
 * Creates a new blank countdown event with a 7-day default target in DD/MM/YYYY.
 */
function createNewEvent(title) {
  var d = new Date();
  d.setDate(d.getDate() + 7);
  var pad = function(n) { return n < 10 ? "0" + n : String(n); };
  var dateStr = pad(d.getDate()) + "/" + pad(d.getMonth() + 1) + "/" + d.getFullYear();

  return {
    id: "evt_" + Date.now(),
    title: title || "New Event",
    targetDate: dateStr,
    startDate: new Date().toISOString(),
    iconStyle: "calendar",
    customEmoji: ""
  };
}

/**
 * Safely adds N months to a date without overflowing past month boundaries (e.g. Jan 31 -> Feb 28).
 */
function addMonthsSafe(date, n) {
  var d = date.getDate();
  var y = date.getFullYear();
  var m = date.getMonth() + n;
  var targetY = y + Math.floor(m / 12);
  var targetM = (m % 12 + 12) % 12;
  var maxDays = new Date(targetY, targetM + 1, 0).getDate();
  return new Date(targetY, targetM, Math.min(d, maxDays), date.getHours(), date.getMinutes(), date.getSeconds());
}

/**
 * Safely adds N years to a date without overflowing past leap year boundaries (e.g. Feb 29 -> Feb 28).
 */
function addYearsSafe(date, n) {
  var d = date.getDate();
  var m = date.getMonth();
  var targetY = date.getFullYear() + n;
  var maxDays = new Date(targetY, m + 1, 0).getDate();
  return new Date(targetY, m, Math.min(d, maxDays), date.getHours(), date.getMinutes(), date.getSeconds());
}

/**
 * Helper to construct and validate local Date object at 00:00:00.
 */
function createValidDate(y, m, d) {
  if (m < 0 || m > 11 || d < 1 || d > 31) return null;
  var target = new Date(y, m, d, 0, 0, 0);
  if (isNaN(target.getTime())) return null;
  if (target.getFullYear() !== y || target.getMonth() !== m || target.getDate() !== d) return null;
  return target;
}

/**
 * Universal flexible date parser.
 * Parses Day/Month/Year (DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY), ISO (YYYY-MM-DD),
 * Named Month strings ("1 Aug 2027", "Aug 1 2027"), and relative keywords ("tomorrow", "+30d", "next week").
 */
function parseTargetDate(inputStr, now) {
  var base = now instanceof Date ? new Date(now.getTime()) : new Date();
  base.setHours(0, 0, 0, 0);

  if (!inputStr || typeof inputStr !== "string" || inputStr.trim() === "") {
    var def = new Date(base.getTime());
    def.setDate(def.getDate() + 7);
    return def;
  }

  var s = inputStr.trim().toLowerCase();

  // 1. Relative keyword shortcuts
  if (s === "tomorrow" || s === "+1d") {
    var d = new Date(base.getTime()); d.setDate(d.getDate() + 1); return d;
  }
  if (s === "next week" || s === "+1w") {
    var d = new Date(base.getTime()); d.setDate(d.getDate() + 7); return d;
  }
  if (s === "next month" || s === "+1m") {
    return addMonthsSafe(base, 1);
  }
  if (s === "next year" || s === "+1y") {
    return addYearsSafe(base, 1);
  }
  if (s === "end_month" || s === "end of month" || s === "end month") {
    return new Date(base.getFullYear(), base.getMonth() + 1, 0, 0, 0, 0);
  }
  if (s === "end_year" || s === "end of year" || s === "end year") {
    return new Date(base.getFullYear(), 11, 31, 0, 0, 0);
  }

  // 2. Relative offsets: +10d, 10 days, in 30 days, +2w, +3m, +1y
  var relMatch = s.match(/^(?:\+|\bin\s+)?(\d+)\s*(d|day|days|w|week|weeks|m|mo|month|months|y|yr|year|years)$/);
  if (relMatch) {
    var count = parseInt(relMatch[1], 10);
    var unit = relMatch[2];
    if (unit.startsWith("d")) {
      var d = new Date(base.getTime()); d.setDate(d.getDate() + count); return d;
    } else if (unit.startsWith("w")) {
      var d = new Date(base.getTime()); d.setDate(d.getDate() + count * 7); return d;
    } else if (unit.startsWith("m")) {
      return addMonthsSafe(base, count);
    } else if (unit.startsWith("y")) {
      return addYearsSafe(base, count);
    }
  }

  // Clean ordinal suffixes: 1st, 2nd, 3rd, 4th -> 1, 2, 3, 4
  var cleanStr = s.replace(/(\d+)(st|nd|rd|th)/g, "$1").replace(/,/g, " ").replace(/\s+/g, " ").trim();

  // 3. ISO format: YYYY-MM-DD, YYYY/MM/DD, YYYY.MM.DD
  var isoMatch = cleanStr.match(/^(\d{4})[-\/\.](\d{1,2})[-\/\.](\d{1,2})$/);
  if (isoMatch) {
    var y = parseInt(isoMatch[1], 10);
    var m = parseInt(isoMatch[2], 10) - 1;
    var d = parseInt(isoMatch[3], 10);
    return createValidDate(y, m, d);
  }

  // 4. Day-First format: DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY, DD/MM/YY
  var dmyMatch = cleanStr.match(/^(\d{1,2})[-\/\.](\d{1,2})[-\/\.](\d{2,4})$/);
  if (dmyMatch) {
    var d = parseInt(dmyMatch[1], 10);
    var m = parseInt(dmyMatch[2], 10) - 1;
    var y = parseInt(dmyMatch[3], 10);
    if (y < 100) y += (y < 50 ? 2000 : 1900);
    return createValidDate(y, m, d);
  }

  // 5. Named Month: DD Month YYYY (e.g. "1 Aug 2027", "23 August 2027")
  var dmyNamed = cleanStr.match(/^(\d{1,2})\s+([a-z]+)(?:\s+(\d{2,4}))?$/);
  if (dmyNamed && MONTH_NAMES[dmyNamed[2]] !== undefined) {
    var d = parseInt(dmyNamed[1], 10);
    var m = MONTH_NAMES[dmyNamed[2]];
    var y = dmyNamed[3] ? parseInt(dmyNamed[3], 10) : base.getFullYear();
    if (y < 100) y += (y < 50 ? 2000 : 1900);
    var res = createValidDate(y, m, d);
    if (!dmyNamed[3] && res && res < base) {
      res = createValidDate(y + 1, m, d);
    }
    return res;
  }

  // 6. Named Month: Month DD YYYY (e.g. "Aug 1 2027", "August 1 2027")
  var mdyNamed = cleanStr.match(/^([a-z]+)\s+(\d{1,2})(?:\s+(\d{2,4}))?$/);
  if (mdyNamed && MONTH_NAMES[mdyNamed[1]] !== undefined) {
    var m = MONTH_NAMES[mdyNamed[1]];
    var d = parseInt(mdyNamed[2], 10);
    var y = mdyNamed[3] ? parseInt(mdyNamed[3], 10) : base.getFullYear();
    if (y < 100) y += (y < 50 ? 2000 : 1900);
    var res = createValidDate(y, m, d);
    if (!mdyNamed[3] && res && res < base) {
      res = createValidDate(y + 1, m, d);
    }
    return res;
  }

  // 7. Short numeric DD/MM or DD-MM
  var dmShort = cleanStr.match(/^(\d{1,2})[-\/\.](\d{1,2})$/);
  if (dmShort) {
    var d = parseInt(dmShort[1], 10);
    var m = parseInt(dmShort[2], 10) - 1;
    var y = base.getFullYear();
    var res = createValidDate(y, m, d);
    if (res && res < base) res = createValidDate(y + 1, m, d);
    return res;
  }

  return null;
}

/**
 * Validates whether a date string is parseable.
 */
function isValidDate(dateStr) {
  if (!dateStr || typeof dateStr !== "string" || dateStr.trim() === "") return false;
  return parseTargetDate(dateStr) !== null;
}

/**
 * Formats a Date object as DD/MM/YYYY.
 */
function formatDateDisplay(date) {
  if (!(date instanceof Date) || isNaN(date.getTime())) return "";
  var pad = function(n) { return n < 10 ? "0" + n : String(n); };
  return pad(date.getDate()) + "/" + pad(date.getMonth() + 1) + "/" + date.getFullYear();
}

/**
 * Formats a Date object as clean readable string (e.g. "1 Aug 2027").
 */
function formatDateNamed(date) {
  if (!(date instanceof Date) || isNaN(date.getTime())) return "";
  return date.getDate() + " " + SHORT_MONTH_NAMES[date.getMonth()] + " " + date.getFullYear();
}

/**
 * Formats a Date object as ISO YYYY-MM-DD.
 */
function formatDateISO(date) {
  if (!(date instanceof Date) || isNaN(date.getTime())) return "";
  var pad = function(n) { return n < 10 ? "0" + n : String(n); };
  return date.getFullYear() + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate());
}

/**
 * Calculates preset target dates in clean DD/MM/YYYY format.
 */
function getPresetDate(type, now) {
  var base = now instanceof Date ? new Date(now.getTime()) : new Date();
  base.setHours(0, 0, 0, 0);

  switch (type) {
    case "+1d":
      base.setDate(base.getDate() + 1);
      return formatDateDisplay(base);

    case "+1w":
      base.setDate(base.getDate() + 7);
      return formatDateDisplay(base);

    case "+1m":
      base = addMonthsSafe(base, 1);
      return formatDateDisplay(base);

    case "+1y":
      base = addYearsSafe(base, 1);
      return formatDateDisplay(base);

    case "end_month":
      var lastDay = new Date(base.getFullYear(), base.getMonth() + 1, 0, 0, 0, 0);
      return formatDateDisplay(lastDay);

    case "end_year":
      var endYear = new Date(base.getFullYear(), 11, 31, 0, 0, 0);
      return formatDateDisplay(endYear);

    default:
      return formatDateDisplay(base);
  }
}

/**
 * Calendar-aware countdown calculation.
 * Accurately calculates standard breakdown and total accumulated units.
 */
function calculateCountdown(targetDateStr, now, startDateStr) {
  var current = now instanceof Date ? now : new Date();
  var target = parseTargetDate(targetDateStr, current);

  if (!target) return null;

  var diffMs = target.getTime() - current.getTime();
  var isPast = diffMs < 0;
  var isExpired = diffMs <= 0;

  var start = isPast ? target : current;
  var end = isPast ? current : target;

  var totalMs = Math.abs(diffMs);
  var totalSeconds = Math.floor(totalMs / 1000);
  var totalMinutes = Math.floor(totalSeconds / 60);
  var totalHours = Math.floor(totalMinutes / 60);
  var totalDays = Math.floor(totalHours / 24);

  // Calendar-accurate breakdown using safe step arithmetic
  var temp = new Date(start.getTime());

  var years = 0;
  while (true) {
    var nextY = addYearsSafe(start, years + 1);
    if (nextY <= end) {
      years++;
      temp = nextY;
    } else {
      break;
    }
  }

  var baseAfterYears = new Date(temp.getTime());
  var months = 0;
  while (true) {
    var nextM = addMonthsSafe(baseAfterYears, months + 1);
    if (nextM <= end) {
      months++;
      temp = nextM;
    } else {
      break;
    }
  }

  var days = 0;
  while (true) {
    var nextD = new Date(temp.getFullYear(), temp.getMonth(), temp.getDate() + 1, temp.getHours(), temp.getMinutes(), temp.getSeconds());
    if (nextD <= end) {
      days++;
      temp = nextD;
    } else {
      break;
    }
  }

  var hours = 0;
  while (true) {
    var nextH = new Date(temp.getFullYear(), temp.getMonth(), temp.getDate(), temp.getHours() + 1, temp.getMinutes(), temp.getSeconds());
    if (nextH <= end) {
      hours++;
      temp = nextH;
    } else {
      break;
    }
  }

  var minutes = 0;
  while (true) {
    var nextMin = new Date(temp.getFullYear(), temp.getMonth(), temp.getDate(), temp.getHours(), temp.getMinutes() + 1, temp.getSeconds());
    if (nextMin <= end) {
      minutes++;
      temp = nextMin;
    } else {
      break;
    }
  }

  var seconds = Math.floor((end.getTime() - temp.getTime()) / 1000);

  // Baseline start calculation for percentage progression
  var baselineDate = null;
  if (startDateStr && typeof startDateStr === "string" && startDateStr.trim() !== "") {
    var parsedStart = new Date(startDateStr);
    if (!isNaN(parsedStart.getTime()) && parsedStart < target) {
      baselineDate = parsedStart;
    }
  }

  if (!baselineDate) {
    baselineDate = new Date(current.getFullYear(), 0, 1, 0, 0, 0);
    if (baselineDate >= target) {
      baselineDate = new Date(target.getTime() - Math.max(diffMs, 7 * 24 * 3600 * 1000));
    }
  }

  var totalSpanMs = target.getTime() - baselineDate.getTime();
  var ratioRemaining = 1.0;
  var ratioElapsed = 0.0;

  if (totalSpanMs > 0) {
    if (isPast) {
      ratioRemaining = 0.0;
      ratioElapsed = 1.0;
    } else {
      ratioRemaining = Math.max(0.0, Math.min(1.0, diffMs / totalSpanMs));
      ratioElapsed = 1.0 - ratioRemaining;
    }
  }

  var percentRemaining = ratioRemaining * 100.0;
  var percentElapsed = ratioElapsed * 100.0;

  return {
    target: target,
    current: current,
    baselineDate: baselineDate,
    years: years,
    months: months,
    days: days,
    hours: hours,
    minutes: minutes,
    seconds: seconds,
    totalDays: totalDays,
    totalHours: totalHours,
    totalMinutes: totalMinutes,
    totalSeconds: totalSeconds,
    totalMs: totalMs,
    isPast: isPast,
    isExpired: isExpired,
    ratioRemaining: ratioRemaining,
    ratioElapsed: ratioElapsed,
    percentRemaining: percentRemaining,
    percentElapsed: percentElapsed,
    percentStr: percentElapsed.toFixed(0) + "%"
  };
}

/**
 * Computes active units dynamically according to which units are enabled.
 * If Years or Months are disabled, their values roll over into Days/Hours/Minutes.
 */
function getActiveUnitValues(stats, settings) {
  if (!stats) return { years: 0, months: 0, days: 0, hours: 0, minutes: 0, seconds: 0 };

  var showY = settings ? settings.showYears !== false : true;
  var showM = settings ? settings.showMonths !== false : true;
  var showD = settings ? settings.showDays !== false : true;
  var showH = settings ? settings.showHours !== false : true;
  var showMin = settings ? settings.showMinutes !== false : true;

  var current = stats.current;
  var target = stats.target;
  var start = stats.isPast ? target : current;
  var end = stats.isPast ? current : target;
  var temp = new Date(start.getTime());

  var years = 0;
  if (showY) {
    while (true) {
      var nextY = addYearsSafe(start, years + 1);
      if (nextY <= end) {
        years++;
        temp = nextY;
      } else break;
    }
  }

  var baseAfterYears = new Date(temp.getTime());
  var months = 0;
  if (showM) {
    while (true) {
      var nextM = addMonthsSafe(baseAfterYears, months + 1);
      if (nextM <= end) {
        months++;
        temp = nextM;
      } else break;
    }
  }

  var days = 0;
  if (showD) {
    while (true) {
      var nextD = new Date(temp.getFullYear(), temp.getMonth(), temp.getDate() + 1, temp.getHours(), temp.getMinutes(), temp.getSeconds());
      if (nextD <= end) {
        days++;
        temp = nextD;
      } else break;
    }
  }

  var hours = 0;
  if (showH) {
    while (true) {
      var nextH = new Date(temp.getFullYear(), temp.getMonth(), temp.getDate(), temp.getHours() + 1, temp.getMinutes(), temp.getSeconds());
      if (nextH <= end) {
        hours++;
        temp = nextH;
      } else break;
    }
  }

  var minutes = 0;
  if (showMin) {
    while (true) {
      var nextMin = new Date(temp.getFullYear(), temp.getMonth(), temp.getDate(), temp.getHours(), temp.getMinutes() + 1, temp.getSeconds());
      if (nextMin <= end) {
        minutes++;
        temp = nextMin;
      } else break;
    }
  }

  var seconds = Math.floor((end.getTime() - temp.getTime()) / 1000);

  return {
    years: years,
    months: months,
    days: days,
    hours: hours,
    minutes: minutes,
    seconds: seconds
  };
}

/**
 * Formats the bar text according to settings and format styles.
 */
function formatBarText(stats, settings) {
  if (!stats) return "No Target";

  var fmt = settings ? settings.format : "auto";
  var showLabel = settings ? settings.showLabel : true;
  var targetLabel = settings && settings.targetLabel ? settings.targetLabel.trim() : "";

  var prefix = (showLabel && targetLabel !== "") ? (targetLabel + " ") : "";

  if (fmt === "percentage") {
    return prefix + stats.percentStr;
  }

  if (fmt === "days_only") {
    return prefix + (stats.isPast ? "-" : "") + stats.totalDays + "d";
  }

  if (fmt === "hours_only") {
    return prefix + (stats.isPast ? "-" : "") + stats.totalHours + "h";
  }

  var u = getActiveUnitValues(stats, settings);
  var parts = [];

  if (settings ? settings.showYears : true) {
    if (u.years > 0 || fmt === "full") parts.push(u.years + "y");
  }
  if (settings ? settings.showMonths : true) {
    if (u.months > 0 || fmt === "full" || (parts.length > 0 && fmt === "auto")) parts.push(u.months + "mo");
  }
  if (settings ? settings.showDays : true) {
    if (u.days > 0 || fmt === "full" || (parts.length > 0 && fmt === "auto")) parts.push(u.days + "d");
  }
  if (settings ? settings.showHours : true) {
    if (u.hours > 0 || fmt === "full" || (parts.length > 0 && fmt === "auto")) parts.push(u.hours + "h");
  }
  if (settings ? settings.showMinutes : true) {
    if (u.minutes > 0 || fmt === "full" || parts.length === 0) parts.push(u.minutes + "m");
  }

  if (parts.length === 0) {
    parts.push(stats.totalDays + "d");
  }

  if (fmt === "compact") {
    parts = parts.slice(0, 2);
  }

  var res = (stats.isPast ? "-" : "") + parts.join(" ");
  return prefix + res;
}

/**
 * Returns a detailed multiline breakdown string for popups and tooltips.
 */
function formatDetailed(stats, settings) {
  if (!stats) return "No target date set";

  var u = getActiveUnitValues(stats, settings);
  var parts = [];

  if ((settings ? settings.showYears : true) && u.years > 0) parts.push(u.years + "y");
  if ((settings ? settings.showMonths : true) && u.months > 0) parts.push(u.months + "mo");
  if ((settings ? settings.showDays : true) && (u.days > 0 || parts.length > 0)) parts.push(u.days + "d");
  if (settings ? settings.showHours : true) parts.push(u.hours + "h");
  if (settings ? settings.showMinutes : true) parts.push(u.minutes + "m");

  if (parts.length === 0) {
    parts.push(stats.totalDays + "d " + stats.hours + "h " + stats.minutes + "m");
  }

  return (stats.isPast ? "Elapsed: " : "") + parts.join(" ");
}

/**
 * Returns icon character / glyph.
 * Uses authentic Omarchy Nerd Font glyphs that respect system colors and themes.
 */
function getIcon(iconStyle, customEmoji) {
  switch (iconStyle) {
    case "medical":
      return "\uf0f1"; // nf-fa-stethoscope (genuine Font Awesome stethoscope)
    case "clock":
      return "\uf017"; // nf-fa-clock_o
    case "hourglass":
      return "\uf252"; // nf-fa-hourglass
    case "calendar":
      return "\uf073"; // nf-fa-calendar
    case "target":
      return "\uf140"; // nf-fa-bullseye
    case "grad":
      return "\uf19d"; // nf-fa-graduation_cap
    case "book":
      return "\uf02d"; // nf-fa-book
    case "star":
      return "\uf005"; // nf-fa-star
    case "plane":
      return "\uf072"; // nf-fa-plane
    case "heart":
      return "\uf004"; // nf-fa-heart
    case "bolt":
      return "\uf0e7"; // nf-fa-bolt
    case "custom":
      return (customEmoji && customEmoji.trim() !== "") ? customEmoji.trim() : "\uf0f1";
    case "none":
      return "";
    default:
      return "\uf0f1";
  }
}

/**
 * Computes calibrated dynamic timeline gradient color from Green -> Yellow -> Orange -> Red.
 * Correctly accounts for long-range events (e.g. 1 year away is 100% Pure Green)
 * as well as short-range countdowns.
 */
function getProgressColor(stats) {
  if (!stats || stats.isPast) return "#ff5555"; // Red / Expired

  var days = stats.totalDays !== undefined ? stats.totalDays : 0;
  var hours = stats.totalHours !== undefined ? stats.totalHours : 0;
  var ratioRem = stats.ratioRemaining !== undefined ? stats.ratioRemaining : 1.0;

  // Calibrated ratio based on horizon and relative duration
  var r = 1.0;
  if (days >= 60) {
    r = 1.0; // 100% Pure Green (events > 2 months away)
  } else if (days >= 21) {
    // 60d to 21d: Green (1.0) down to Lime (0.70)
    r = 0.70 + (0.30 * (days - 21) / 39.0);
  } else if (days >= 7) {
    // 21d to 7d: Lime (0.70) down to Warm Yellow (0.40)
    r = 0.40 + (0.30 * (days - 7) / 14.0);
  } else if (days >= 2) {
    // 7d to 2d: Warm Yellow (0.40) down to Vivid Orange (0.15)
    r = 0.15 + (0.25 * (days - 2) / 5.0);
  } else {
    // < 2 days (48h down to 0): Vivid Orange (0.15) down to Crimson Red (0.0)
    r = Math.max(0.0, 0.15 * (hours / 48.0));
  }

  // If user configured a specific start date with higher relative remaining ratio, respect it
  if (ratioRem > r) {
    r = ratioRem;
  }

  // 4-stop smooth RGB color interpolation
  var red = 0;
  var green = 0;
  var blue = 0;

  if (r >= 0.6) {
    // Green (1.0) to Yellow (0.6)
    var t = (r - 0.6) / 0.4;
    red = Math.round(241 + (80 - 241) * t);
    green = Math.round(250 + (250 - 250) * t);
    blue = Math.round(140 + (123 - 140) * t);
  } else if (r >= 0.25) {
    // Yellow (0.6) to Orange (0.25)
    var t = (r - 0.25) / 0.35;
    red = Math.round(255 + (241 - 255) * t);
    green = Math.round(184 + (250 - 184) * t);
    blue = Math.round(108 + (140 - 108) * t);
  } else {
    // Orange (0.25) to Red (0.0)
    var t = r / 0.25;
    red = Math.round(255 + (255 - 255) * t);
    green = Math.round(85 + (184 - 85) * t);
    blue = Math.round(85 + (108 - 85) * t);
  }

  var hexR = (red < 16 ? "0" : "") + red.toString(16);
  var hexG = (green < 16 ? "0" : "") + green.toString(16);
  var hexB = (blue < 16 ? "0" : "") + blue.toString(16);

  return "#" + hexR + hexG + hexB;
}

/**
 * Checks if the countdown triggers an urgent state.
 */
function isUrgent(stats, thresholdDays) {
  if (!stats || thresholdDays <= 0 || stats.isPast) return false;
  return stats.totalDays <= thresholdDays;
}

/**
 * Cycles to the next available display format.
 */
function nextFormat(current) {
  var formats = ["auto", "full", "compact", "days_only", "hours_only", "percentage"];
  var idx = formats.indexOf(current);
  if (idx === -1) return formats[0];
  return formats[(idx + 1) % formats.length];
}

/**
 * Cycles to the next available icon style.
 */
function nextIconStyle(current) {
  var styles = ["medical", "clock", "hourglass", "calendar", "target", "grad", "book", "star", "plane", "heart", "bolt", "custom", "none"];
  var idx = styles.indexOf(current);
  if (idx === -1) return styles[0];
  return styles[(idx + 1) % styles.length];
}

/**
 * Cycles to the next available visual presentation style.
 */
function nextStyle(current) {
  var styles = ["ghost", "accent_text", "progress_track", "dynamic_progress"];
  var idx = styles.indexOf(current);
  if (idx === -1) return styles[0];
  return styles[(idx + 1) % styles.length];
}



