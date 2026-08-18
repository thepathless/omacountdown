// Model.js - Core calendar math, unit breakdown, formatters, and presets for OmaCountdown
.pragma library

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

  // Calendar-accurate breakdown
  var temp = new Date(start.getTime());

  var years = 0;
  while (true) {
    var nextY = new Date(temp.getFullYear() + 1, temp.getMonth(), temp.getDate(), temp.getHours(), temp.getMinutes(), temp.getSeconds());
    if (nextY <= end) {
      years++;
      temp = nextY;
    } else {
      break;
    }
  }

  var months = 0;
  while (true) {
    var nextM = new Date(temp.getFullYear(), temp.getMonth() + 1, temp.getDate(), temp.getHours(), temp.getMinutes(), temp.getSeconds());
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

  // Total baseline duration for percentage milestones (from startDate to target)
  var baselineDate = null;
  if (startDateStr && startDateStr.trim() !== "") {
    var parsedStart = new Date(startDateStr);
    if (!isNaN(parsedStart.getTime()) && parsedStart < target) {
      baselineDate = parsedStart;
    }
  }
  if (!baselineDate) {
    // Default baseline: Jan 1 of current year or 30 days prior
    var yearStart = new Date(current.getFullYear(), 0, 1, 0, 0, 0);
    baselineDate = (yearStart < target) ? yearStart : new Date(target.getTime() - 30 * 86400000);
  }

  var totalSpan = Math.max(1000, target.getTime() - baselineDate.getTime());
  var remainingSpan = isPast ? 0 : Math.max(0, target.getTime() - current.getTime());
  var ratioRemaining = Math.min(1.0, Math.max(0.0, remainingSpan / totalSpan));
  var percentRemaining = ratioRemaining * 100;
  var ratioElapsed = Math.min(1.0, Math.max(0.0, 1.0 - ratioRemaining));
  var percentElapsed = ratioElapsed * 100;

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
 * If Years or Months are disabled, their values roll over into Days/Hours/Minutes!
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
      var nextY = new Date(temp.getFullYear() + 1, temp.getMonth(), temp.getDate(), temp.getHours(), temp.getMinutes(), temp.getSeconds());
      if (nextY <= end) {
        years++;
        temp = nextY;
      } else break;
    }
  }

  var months = 0;
  if (showM) {
    while (true) {
      var nextM = new Date(temp.getFullYear(), temp.getMonth() + 1, temp.getDate(), temp.getHours(), temp.getMinutes(), temp.getSeconds());
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
 * Formats the bar widget text respecting enabled units and format style.
 */
function formatBarText(stats, settings) {
  if (!stats) return settings && settings.targetLabel ? settings.targetLabel : "Countdown";

  var showY = settings ? settings.showYears !== false : true;
  var showM = settings ? settings.showMonths !== false : true;
  var showD = settings ? settings.showDays !== false : true;
  var showH = settings ? settings.showHours !== false : true;
  var showMin = settings ? settings.showMinutes !== false : true;
  var showLbl = settings ? settings.showLabel !== false : true;
  var label = (showLbl && settings && settings.targetLabel && settings.targetLabel.trim() !== "") ? settings.targetLabel.trim() : "";
  var format = settings && settings.format ? settings.format : "auto";

  if (format === "percentage") {
    return (label !== "" ? label + " " : "") + (stats.isPast ? "100%" : stats.percentStr);
  }

  if (format === "days_only") {
    var dStr = stats.totalDays + "d";
    if (stats.isPast) dStr += " ago";
    return (label !== "" ? label + " " : "") + dStr;
  }

  if (format === "hours_only") {
    var hStr = stats.totalHours + "h";
    if (stats.isPast) hStr += " ago";
    return (label !== "" ? label + " " : "") + hStr;
  }

  var units = getActiveUnitValues(stats, settings);
  var parts = [];

  if (showY && units.years > 0) parts.push(units.years + "y");
  if (showM && units.months > 0) parts.push(units.months + "mo");
  if (showD && units.days > 0) parts.push(units.days + "d");
  if (showH && units.hours > 0) parts.push(units.hours + "h");
  if (showMin && units.minutes > 0) parts.push(units.minutes + "m");

  if (parts.length === 0) {
    if (showMin) parts.push(units.minutes + "m");
    else if (showH) parts.push(units.hours + "h");
    else if (showD) parts.push(units.days + "d");
    else parts.push("0m");
  }

  var timeStr = "";
  if (format === "compact") {
    timeStr = parts.slice(0, 2).join(" ");
  } else if (format === "full") {
    timeStr = parts.join(" ");
  } else {
    // "auto": smart adaptive (max 3 non-zero units)
    timeStr = parts.slice(0, 3).join(" ");
  }

  if (stats.isPast) {
    timeStr += " ago";
  }

  return (label !== "" ? label + " " : "") + timeStr;
}

/**
 * Formats full detailed breakdown string (respects active units or full breakdown).
 */
function formatDetailed(stats, settings) {
  if (!stats) return "No target date set";
  var units = getActiveUnitValues(stats, settings || { showYears: true, showMonths: true, showDays: true, showHours: true, showMinutes: true });
  var parts = [];
  if (units.years > 0) parts.push(units.years + "y");
  if (units.months > 0) parts.push(units.months + "mo");
  if (units.days > 0) parts.push(units.days + "d");
  if (units.hours > 0) parts.push(units.hours + "h");
  if (units.minutes > 0) parts.push(units.minutes + "m");
  if (units.seconds > 0 || parts.length === 0) parts.push(units.seconds + "s");
  return parts.join(" ") + (stats.isPast ? " ago" : "");
}

/**
 * Returns icon character / glyph.
 * Uses authentic Omarchy Nerd Font glyphs that respect system colors and themes.
 */
function getIcon(iconStyle, customEmoji) {
  switch (iconStyle) {
    case "medical":
      return "\uf0f0"; // nf-fa-user_md / stethoscope
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
      return (customEmoji && customEmoji.trim() !== "") ? customEmoji.trim() : "\uf0f0";
    case "none":
      return "";
    default:
      return "\uf0f0";
  }
}

/**
 * Computes dynamic timeline gradient color from Green -> Yellow -> Orange -> Red
 * based on the percentage of time remaining (1.0 = 100% left to 0.0 = 0% left).
 */
function getProgressColor(ratioRemaining, isPast) {
  if (isPast) return "#ff5555"; // Red / Expired

  var r = Math.min(1.0, Math.max(0.0, ratioRemaining));

  // 4-stop gradient:
  // 1.0 -> Lush Green (rgb: 80, 250, 123)
  // 0.6 -> Warm Gold / Yellow (rgb: 241, 250, 140)
  // 0.25 -> Coral / Orange (rgb: 255, 184, 108)
  // 0.0 -> Crimson / Red (rgb: 255, 85, 85)

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
      base.setMonth(base.getMonth() + 1);
      return formatDateISO(base);

    case "+1y":
      base.setFullYear(base.getFullYear() + 1);
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
  var styles = ["flat", "pill", "progress"];
  var idx = styles.indexOf(current);
  if (idx === -1) return styles[0];
  return styles[(idx + 1) % styles.length];
}

/**
 * Checks percentage milestone crossings (100%, 90%, 80%, ..., 10%, 0%).
 * Note: Notification text contains ONLY the remaining time amount, NO percentage symbol!
 */
function checkMilestone(prevStats, currentStats, settings) {
  if (!prevStats || !currentStats || currentStats.isPast) return null;

  var thresholds = [90, 80, 70, 60, 50, 40, 30, 20, 10, 0];
  var prevPct = prevStats.percentRemaining;
  var currPct = currentStats.percentRemaining;

  for (var i = 0; i < thresholds.length; i++) {
    var t = thresholds[i];
    if (prevPct > t && currPct <= t) {
      var remainingFormatted = formatBarText(currentStats, {
        showYears: settings ? settings.showYears : true,
        showMonths: settings ? settings.showMonths : true,
        showDays: settings ? settings.showDays : true,
        showHours: settings ? settings.showHours : true,
        showMinutes: settings ? settings.showMinutes : true,
        format: "full",
        showLabel: false
      });

      return {
        threshold: t,
        remainingText: remainingFormatted
      };
    }
  }

  return null;
}


