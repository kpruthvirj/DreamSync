public with sharing class CarbonConsultationInviteService {

    public enum METHOD {
        REQUEST, PUBLISH, CANCEL
    }
    public enum ICS_CONTENT_TYPE {
        TEXT_CALENDAR
    }

    // RFC 5545 requires CRLF line terminators
    private static final String CRLF = '\r\n';

    public class InvocableRequest {
        @InvocableVariable(required=true)
        public String recipientEmail;
        @InvocableVariable(required=true)
        public String interest;

        @InvocableVariable
        public Datetime startDateTime; // If null, defaults to next business day 10:00 AM org tz
        @InvocableVariable
        public Datetime endDateTime;   // If null, start + 30 minutes

        @InvocableVariable
        public String timeZone;

        @InvocableVariable
        public String subjectOverride;
        @InvocableVariable
        public String descriptionOverride;
        @InvocableVariable
        public String location;
        @InvocableVariable
        public String meetingUrl;
        @InvocableVariable
        public String additionalAttendees;
        @InvocableVariable
        public String organizerEmail;

        @InvocableVariable
        public String method;
    }


    public class InvocableResult {
        @InvocableVariable
        public Boolean success;
        @InvocableVariable
        public String message;
        @InvocableVariable
        public String recipientEmail;
        @InvocableVariable
        public String uid;
    }


    @InvocableMethod(label='Send Carbon Consultation Calendar Invites' description='Send email calendar invites to book a Carbon Consultation based on interest.')
    public static List<InvocableResult> sendInvites(List<InvocableRequest> requests) {
        List<InvocableResult> results = new List<InvocableResult>();
        if (requests == null || requests.isEmpty()) {
            return results;
        }

        String orgTzId = UserInfo.getTimeZone().getID();
        String orgLocale = UserInfo.getLocale();
        String orgEmail = UserInfo.getUserEmail();

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<String> uids = new List<String>();

        for (InvocableRequest req : requests) {
            InvocableResult res = new InvocableResult();
            res.recipientEmail = req != null ? req.recipientEmail : null;

            try {
                if (req == null) {
                    results.add(errorResult(res, 'Request is null'));
                    continue;
                }
                if (String.isBlank(req.recipientEmail)) {
                    results.add(errorResult(res, 'recipientEmail is required'));
                    continue;
                }
                if (String.isBlank(req.interest)) {
                    results.add(errorResult(res, 'interest is required'));
                    continue;
                }

                // Determine timezone
                String tz = String.isBlank(req.timeZone) ? orgTzId : req.timeZone;

                Datetime startDt = req.startDateTime;
                if (startDt == null) {
                    startDt = defaultStartDateTime(tz);
                }
                Datetime endDt = req.endDateTime != null ? req.endDateTime : startDt.addMinutes(30);


                String subject = !String.isBlank(req.subjectOverride)
                    ? req.subjectOverride
                    : 'Carbon Consultation - ' + req.interest;
                String description = !String.isBlank(req.descriptionOverride)
                    ? req.descriptionOverride
                    : 'Thank you for your interest in a Carbon Consultation related to: ' + req.interest +
                      '. This calendar invite reserves time with our team. ' +
                      (String.isBlank(req.meetingUrl) ? '' : 'Join URL: ' + req.meetingUrl);

                String organizer = !String.isBlank(req.organizerEmail) ? req.organizerEmail : orgEmail;


                List<String> attendees = new List<String>();
                attendees.add(req.recipientEmail.trim());
                if (!String.isBlank(req.additionalAttendees)) {
                    for (String a : req.additionalAttendees.split(';')) {
                        if (!String.isBlank(a)) {
                            attendees.add(a.trim());
                        }
                    }
                }

                String uid = generateUid();
                String method = String.isBlank(req.method) ? String.valueOf(METHOD.REQUEST) : req.method;

                String ics = buildIcs(
                    subject,
                    description,
                    organizer,
                    attendees,
                    startDt,
                    endDt,
                    tz,
                    req.location,
                    req.meetingUrl,
                    uid,
                    method
                );

                // Validate before we ever attach/send a potentially malformed invite.
                List<String> validationErrors = validateIcs(ics, uid);
                Boolean icsValid = validationErrors.isEmpty();

                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setToAddresses(new List<String>{ req.recipientEmail });
                if (attendees.size() > 1) {
                    // add other attendees as CC to expose recipients; alternatively use setBccAddresses
                    List<String> cc = new List<String>();
                    for (String a : attendees) {
                        if (a != null && a != req.recipientEmail) {
                            cc.add(a);
                        }
                    }
                    if (!cc.isEmpty()) {
                        email.setCcAddresses(cc);
                    }
                }

                if (icsValid) {
                    email.setSubject(subject);
                    email.setPlainTextBody(description);

                    // Attach ICS - "text/calendar; method=REQUEST"
                    Messaging.EmailFileAttachment icsAttachment = new Messaging.EmailFileAttachment();
                    icsAttachment.setFileName('invite.ics');
                    icsAttachment.setInline(false);
                    icsAttachment.setContentType('text/calendar; method=' + method + '; charset=UTF-8');
                    icsAttachment.setBody(Blob.valueOf(ics));
                    email.setFileAttachments(new Messaging.EmailFileAttachment[] { icsAttachment });

                    // Optionally set org-wide email address if organizer is not current user and matches an OWEA
                    // Leaving default sender as current user; admins can adjust via Flow or by passing organizerEmail

                    emails.add(email);
                    uids.add(uid);

                    results.add(successResult(res, 'Email prepared', uid));
                } else {
                    // Fallback: the .ics payload didn't pass validation, so don't attach a broken
                    // calendar file. Send a plain-text confirmation with the meeting details instead,
                    // and be explicit in the result that this is a degraded outcome, not a full success,
                    // so the agent doesn't tell the user a calendar invite went out when it didn't.
                    email.setSubject(subject + ' (details attached below - calendar file unavailable)');
                    email.setPlainTextBody(buildFallbackPlainTextBody(description, startDt, endDt, tz, req.location, req.meetingUrl));

                    emails.add(email);
                    uids.add(uid);

                    InvocableResult fallback = new InvocableResult();
                    fallback.recipientEmail = req.recipientEmail;
                    fallback.uid = uid;
                    fallback.success = false;
                    fallback.message = 'Calendar invite (.ics) failed validation and was not attached: '
                        + String.join(validationErrors, '; ')
                        + '. A plain-text confirmation email was sent instead with the meeting details.';
                    results.add(fallback);
                }
            } catch (Exception e) {
                results.add(errorResult(res, 'Failed to prepare invite: ' + e.getMessage()));
            }
        }

        if (!emails.isEmpty()) {
            try {
                List<Messaging.SendEmailResult> sendResults = Messaging.sendEmail(emails, false);
                Integer i = 0;
                for (Messaging.SendEmailResult ser : sendResults) {
                    if (!ser.isSuccess()) {
                        Integer idx = i;
                        if (idx < results.size()) {
                            InvocableResult r = results[idx];
                            r.success = false;
                            r.message = 'Send failed: ' + collectErrors(ser);
                        }
                    } else {
                    }
                    i++;
                }
            } catch (Exception e) {
                for (InvocableResult r : results) {
                    if (r.success == null || r.success == true) {
                        r.success = false;
                        r.message = 'Bulk send exception: ' + e.getMessage();
                    }
                }
            }
        }

        return results;
    }

    /**
     * Builds an RFC 5545-compliant VCALENDAR/VEVENT payload.
     * Every content line is terminated with CRLF, and every field carries
     * its actual value (previous version emitted bare labels with no data
     * and no line terminators, producing a single malformed line).
     */
    @TestVisible
    private static String buildIcs(
        String subject,
        String description,
        String organizerEmail,
        List<String> attendees,
        Datetime startDt,
        Datetime endDt,
        String timeZoneId,
        String location,
        String meetingUrl,
        String uid,
        String method
    ) {
        Datetime nowUtc = Datetime.now();
        String dtStamp = formatAsUtc(nowUtc);
        String dtStartLocal = formatWithTz(startDt, timeZoneId);
        String dtEndLocal = formatWithTz(endDt, timeZoneId);

        String sanitizedDesc = sanitizeForIcs(description);
        if (!String.isBlank(meetingUrl)) {
            sanitizedDesc += '\\nJoin: ' + meetingUrl;
        }

        String sanitizedLoc = sanitizeForIcs(location);
        String m = String.isBlank(method) ? 'REQUEST' : method;

        String result = '';
        result += 'BEGIN:VCALENDAR' + CRLF;
        result += 'PRODID:-//Carbon Consultation//Salesforce//EN' + CRLF;
        result += 'VERSION:2.0' + CRLF;
        result += 'CALSCALE:GREGORIAN' + CRLF;
        result += 'METHOD:' + m + CRLF;
        // VTIMEZONE block is optional; many clients resolve TZID. Keep it simple to avoid overly long ICS.
        result += 'BEGIN:VEVENT' + CRLF;
        result += 'UID:' + uid + CRLF;
        result += 'DTSTAMP:' + dtStamp + CRLF;
        result += 'SUMMARY:' + escapeText(subject) + CRLF;
        if (!String.isBlank(sanitizedLoc)) {
            result += 'LOCATION:' + escapeText(sanitizedLoc) + CRLF;
        }
        // Use TZID for local times
        result += 'DTSTART;TZID=' + escapeText(timeZoneId) + ':' + dtStartLocal + CRLF;
        result += 'DTEND;TZID=' + escapeText(timeZoneId) + ':' + dtEndLocal + CRLF;
        result += 'ORGANIZER:mailto:' + escapeText(organizerEmail) + CRLF;

        if (attendees != null) {
            for (String a : attendees) {
                if (!String.isBlank(a)) {
                    result += 'ATTENDEE;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;RSVP=TRUE:mailto:' + escapeText(a) + CRLF;
                }
            }
        }

        result += 'DESCRIPTION:' + escapeText(sanitizedDesc) + CRLF;
        result += 'SEQUENCE:0' + CRLF;
        result += 'STATUS:CONFIRMED' + CRLF;
        if (!String.isBlank(meetingUrl)) {
            result += 'URL:' + escapeText(meetingUrl) + CRLF;
        }
        result += 'END:VEVENT' + CRLF;
        result += 'END:VCALENDAR' + CRLF;

        return result;
    }

    /**
     * Lightweight structural validation performed before an ICS payload is
     * ever attached to an outbound email. This is not a full RFC 5545
     * parser - it checks the handful of things that, if missing, are known
     * to produce an invite that "sends fine" but silently fails to import
     * in the recipient's calendar client.
     */
    @TestVisible
    private static List<String> validateIcs(String ics, String expectedUid) {
        List<String> errors = new List<String>();

        if (String.isBlank(ics)) {
            errors.add('ICS content is blank');
            return errors;
        }

        if (!ics.contains('BEGIN:VCALENDAR') || !ics.contains('END:VCALENDAR')) {
            errors.add('Missing VCALENDAR wrapper');
        }
        if (!ics.contains('BEGIN:VEVENT') || !ics.contains('END:VEVENT')) {
            errors.add('Missing VEVENT block');
        }
        if (!ics.contains('UID:' + expectedUid)) {
            errors.add('UID missing or does not match generated value');
        }
        if (!Pattern.matches('(?s).*DTSTAMP:\\d{8}T\\d{6}Z.*', ics)) {
            errors.add('DTSTAMP missing or not in required UTC basic format');
        }
        if (!Pattern.matches('(?s).*DTSTART;TZID=.+:\\d{8}T\\d{6}.*', ics)) {
            errors.add('DTSTART missing or malformed');
        }
        if (!Pattern.matches('(?s).*DTEND;TZID=.+:\\d{8}T\\d{6}.*', ics)) {
            errors.add('DTEND missing or malformed');
        }
        if (!Pattern.matches('(?s).*SUMMARY:.+', ics)) {
            errors.add('SUMMARY missing');
        }
        if (!Pattern.matches('(?s).*ORGANIZER:mailto:.+@.+', ics)) {
            errors.add('ORGANIZER missing or not a valid mailto value');
        }
        if (!ics.contains(CRLF)) {
            errors.add('Content is not CRLF-terminated');
        }

        return errors;
    }

    /**
     * Human-readable fallback used when the .ics payload fails validation.
     * Gives the recipient the same meeting details as plain text so they at
     * least know when/where to show up, even without a calendar attachment.
     */
    @TestVisible
    private static String buildFallbackPlainTextBody(
        String description,
        Datetime startDt,
        Datetime endDt,
        String timeZoneId,
        String location,
        String meetingUrl
    ) {
        String body = description + '\n\n';
        body += 'Meeting details:\n';
        body += '- Start: ' + startDt.format('EEEE, MMMM d, yyyy h:mm a', timeZoneId) + ' (' + timeZoneId + ')\n';
        body += '- End: ' + endDt.format('EEEE, MMMM d, yyyy h:mm a', timeZoneId) + ' (' + timeZoneId + ')\n';
        if (!String.isBlank(location)) {
            body += '- Location: ' + location + '\n';
        }
        if (!String.isBlank(meetingUrl)) {
            body += '- Join URL: ' + meetingUrl + '\n';
        }
        body += '\nNote: we were unable to attach a calendar (.ics) file to this invite. ';
        body += 'Please add this appointment to your calendar manually using the details above.';
        return body;
    }

    // Helpers

    @TestVisible
    private static String sanitizeForIcs(String s) {
        if (String.isBlank(s)) return '';
        // Replace line breaks with \n per ICS escaping rules
        String tmp = s.replace('\r\n', '\\n').replace('\n', '\\n').replace('\r', '\\n');
        return tmp;
    }

    @TestVisible
    private static String escapeText(String s) {
        if (s == null) return '';
        // Escape commas, semicolons, and backslashes
        String out = s.replace('\\', '\\\\').replace(',', '\\,').replace(';', '\\;');
        // Also escape newlines already represented as \n
        return out;
    }

    @TestVisible
    private static String formatAsUtc(Datetime dt) {
        if (dt == null) dt = Datetime.now();
        // ICS UTC format: YYYYMMDDTHHMMSSZ
        return dt.formatGmt('yyyyMMdd\'T\'HHmmss\'Z\'');
    }

    @TestVisible
    private static String formatWithTz(Datetime dt, String tzid) {
        if (dt == null) dt = Datetime.now();
        // For DTSTART;TZID=TZID: use local wall time without Z
        // We'll try formatting using the user's locale; ICS wants basic format.
        // Apex cannot change timezone for format directly; assume dt already in desired timezone context in consumers.
        // Practical approach: use dt.format('yyyyMMdd\'T\'HHmmss') without Z.
        return dt.format('yyyyMMdd\'T\'HHmmss');
    }

    @TestVisible
    private static Datetime defaultStartDateTime(String tzid) {
        // Default next business day at 10:00 AM - naive implementation
        Datetime now = Datetime.now();
        Date d = now.date().addDays(1);
        // skip weekend
        if (d.toStartOfWeek().addDays(5) <= d) { // if Saturday or Sunday
            // move to Monday
            Integer dow = d.toStartOfWeek().daysBetween(d);
            if (dow == 5) { // Saturday
                d = d.addDays(2);
            } else if (dow == 6) { // Sunday
                d = d.addDays(1);
            }
        }
        Time t = Time.newInstance(10, 0, 0, 0);
        return Datetime.newInstance(d, t);
    }

    @TestVisible
    private static String generateUid() {
        return String.valueOf(Crypto.getRandomLong()) + '@salesforce.local';
    }

    private static String collectErrors(Messaging.SendEmailResult ser) {
        String msg = '';
        for (Messaging.SendEmailError e : ser.getErrors()) {
            msg += (String.isBlank(msg) ? '' : '; ') + e.getMessage();
        }
        return msg;
    }

    private static InvocableResult successResult(InvocableResult r, String message, String uid) {
        r.success = true;
        r.message = message;
        r.uid = uid;
        return r;
    }

    private static InvocableResult errorResult(InvocableResult r, String message) {
        r.success = false;
        r.message = message;
        return r;
    }
}