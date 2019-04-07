
import events;


auto logMessage (string severity = "info")(string msg) {
    switch (severity) {
        case "info":    return new LogMessage(LogMessage.Type.Info,     string msg);
        case "warning": return new LogMessage(LogMessage.Type.Warning,  string msg);
        case "error":   return new LogMessage(LogMessage.Type.Error,    string msg);
    }
}
final class LogMessage : public Event {
public:
    enum Type { Info, Warning, Error };
    Type    type;
    string  text;

    this (Type type, string text) {
        this.type = type;
        this.text = text;
    }

    string getDefaultFormatted () {
        switch (message.type) {
            case LogMessage.Type.Info:    return format("%s", message.text);
            case LogMessage.Type.Warning: return format("Warning: %s", message.text);
            case LogMessage.Type.Error:   return format("ERROR:   %s", message.text);
        }
    }
}


class LogWriter {
    this (EventNodeBranch messageBus) {
        messageBus.append(new EventNodeListener!LogMessage(
            getWeakRef(), EventNode.PRIORITY_HIGHEST, &writeMessage));
    }
    // Default implementation; can override
    void writeMessage (LogMessage message) {
        writeln(message.getDefaultFormatted());
    }
}

// Stores a buffered, cyclic array of LogMessages up to maxLength.
// If maxLength <= 0, stores an infinite, non-cycled list of LogMessages.
class LogBuffer (int maxLength = -1) : public LogWriter {
    static if (maxLength <= 0) {
        LogMessage[] messages;
    } else if (maxLength > 0) {
        LogMessage[maxLength] messageStorage;
        typeof(cycle(messageStorage)) messages;
    }
public:
    this (EventNodeBranch messageBus, int maxLength) {
        super(messageBus);
        static if (maxLength > 0) {
            messages = cycle(messageStorage);
        }
    }
    void onMessage (LogMessage message) override {
        messages ~= message;
    }
}


