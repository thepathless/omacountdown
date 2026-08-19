// Model.js - Core calendar math, unit breakdown, formatters, and presets for OmaCountdown
.pragma library

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
 * Parses target date and time strings into a local Date object.
 * Defaults to 7 days ahead if targetDateStr is empty or invalid.
 */
function parseTargetDate(targetDateStr, targetTimeStr, now) {
  var base = now instanceof Date ? now : new Date();

  if (!targetDateStr || targetDateStr.trim() === "") {
    var def = new Date(base.getTime());
    def.setDate(def.getDate() + 7);
    def.setHours(0, 0, 0, 0);
    return def;
  }

  var dMatch = targetDateStr.trim().match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
  if (!dMatch) return null;

  var y = parseInt(dMatch[1], 10);
  var m = parseInt(dMatch[2], 10) - 1;
  var d = parseInt(dMatch[3], 10);

  var h = 0;
  var min = 0;
  var sec = 0;

  if (targetTimeStr && targetTimeStr.trim() !== "") {
    var tMatch = targetTimeStr.trim().match(/^(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?$/);
    if (tMatch) {
      h = parseInt(tMatch[1], 10);
      min = parseInt(tMatch[2], 10);
      if (tMatch[3]) sec = parseInt(tMatch[3], 10);
    }
  }

  var target = new Date(y, m, d, h, min, sec);
  if (isNaN(target.getTime())) return null;
  return target;
}

/**
 * Calendar-aware countdown calculation.
 * Accurately calculates standard breakdown and total accumulated units.
 */
function calculateCountdown(targetDateStr, targetTimeStr, now, startDateStr) {
  var current = now instanceof Date ? now : new Date();
  var target = parseTargetDate(targetDateStr, targetTimeStr, current);

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
  if (startDateStr && startDateStr.trim() !== "") {
    var parsedStart = new Date(startDateStr);
    if (!isNaN(parsedStart.getTime()) && parsedStart < target) {
      baselineDate = parsedStart;
    }
  }

  if (!baselineDate) {
    // If not set, use target minus total duration (or current year start)
    baselineDate = new Date(current.getFullYear(), 0, 1);
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
 * Validates a YYYY-MM-DD date string.
 */
function isValidDate(dateStr) {
  if (!dateStr || dateStr.trim() === "") return false;
  var match = dateStr.trim().match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
  if (!match) return false;
  var y = parseInt(match[1], 10);
  var m = parseInt(match[2], 10);
  var d = parseInt(match[3], 10);
  if (m < 1 || m > 12) return false;
  if (d < 1 || d > 31) return false;
  var test = new Date(y, m - 1, d);
  return test.getFullYear() === y && test.getMonth() === m - 1 && test.getDate() === d;
}

/**
 * Validates a HH:MM time string.
 */
function isValidTime(timeStr) {
  if (!timeStr || timeStr.trim() === "") return true;
  var match = timeStr.trim().match(/^(\d{1,2}):(\d{2})$/);
  if (!match) return false;
  var h = parseInt(match[1], 10);
  var m = parseInt(match[2], 10);
  return h >= 0 && h <= 23 && m >= 0 && m <= 59;
}

/**
 * Formats a Date object as YYYY-MM-DD.
 */
function formatDateISO(date) {
  if (!(date instanceof Date) || isNaN(date.getTime())) return "";
  var y = date.getFullYear();
  var m = (date.getMonth() + 1);
  var d = date.getDate();
  return y + "-" + (m < 10 ? "0" + m : m) + "-" + (d < 10 ? "0" + d : d);
}

/**
 * Formats a Date object as HH:MM.
 */
function formatTimeISO(date) {
  if (!(date instanceof Date) || isNaN(date.getTime())) return "00:00";
  var h = date.getHours();
  var m = date.getMinutes();
  return (h < 10 ? "0" + h : h) + ":" + (m < 10 ? "0" + m : m);
}

/**
 * Calculates preset target dates.
 */
function getPresetDate(type, now) {
  var base = now instanceof Date ? new Date(now.getTime()) : new Date();

  switch (type) {
    case "+1d":
      base.setDate(base.getDate() + 1);
      return formatDateISO(base);

    case "+1w":
      base.setDate(base.getDate() + 7);
      return formatDateISO(base);

    case "+1m":
      base = addMonthsSafe(base, 1);
      return formatDateISO(base);

    case "+1y":
      base = addYearsSafe(base, 1);
      return formatDateISO(base);

    case "end_month":
      var lastDay = new Date(base.getFullYear(), base.getMonth() + 1, 0);
      return formatDateISO(lastDay);

    case "end_year":
      var endYear = new Date(base.getFullYear(), 11, 31);
      return formatDateISO(endYear);

    default:
      return formatDateISO(base);
  }
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
 * Cycles to the next available badge style.
 */
function nextBadgeStyle(current) {
  var styles = ["flat", "flat_progress", "pill", "progress"];
  var idx = styles.indexOf(current);
  if (idx === -1) return styles[0];
  return styles[(idx + 1) % styles.length];
}

