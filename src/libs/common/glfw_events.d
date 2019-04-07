
import event;





auto logMessage (string severity = "info")(string msg) {
    switch (severity) {
        case "info":    return new LogMessage(LogMessage.Type.Info,     string msg);
        case "warning": return new LogMessage(LogMessage.Type.Warning,  string msg);
        case "error":   return new LogMessage(LogMessage.Type.Error,    string msg);
    }
}
class LogWriter {
    this (EventNodeBranch messageBus) {
        messageBus.append(new EventNodeListener!LogMessage(
            getWeakRef(), EventNode.PRIORITY_HIGHEST, &onMessage));
    }
    // Default implementation; can override
    void onMessage (LogMessage message) {
        switch (message.type) {
            case LogMessage.Type.Info:    writefln("%s", message.text); break;
            case LogMessage.Type.Warning: writefln("Warning: %s", message.text); break;
            case LogMessage.Type.Error:   writefln("ERROR:   %s", message.text); break;
        }
    }
}

final class LogMessage {
public:
    enum Type { Info, Warning, Error };
    Type    type;
    string  text;

    this (Type type, string text) {
        this.type = type;
        this.text = text;
    }
}


final class CreateWindow { 
public:
    string name;
    string 
};

class GLFWWindowManager {
    EventNodeBuffer outEvents;
    EventListener   inEventListener;
    EventNodeBuffer inEvents;
public:
    this (EventNode outEvents, out EventNode inEvents) {
        this.outEvents = new EventNodeBuffer(getWeakRef(), outEvents);
        inEvents = this.inEvents = new EventNodeBuffer(getWeakRef(), inEventListener);

        inEventListener.on(&createWindow);
        inEventListener.on(&deleteWindow);
        inEventListener.on(&setWindowTitle);
        inEventListener.on(&setWindowPos);
        inEventListener.on(&setWindowSize);
        inEventListener.on(&setWindowResolution);

        inEventListener.on(&closeApplication);
        inEventListener.on(&cancelCloseApplication);
    }

    void log (string severity, Args...)(Args args) {
        outEvents.handle(logMessage!"warning"(args));
    }




    void createWindow (CreateWindow ev) {
        if (ev.name in windows) {
            outEvents.handle(logMessage!"warning"(
                "Creating duplicate window '%s'; setting properties instead", name));

            setWindowTitle(new SetWindowTitle(ev.name, ev.title));
            setWindowPos(new SetWindowPos(ev.name, ev.pos));
            setWindowPos(new SetWindowSize(ev.name, ev.size));
            setWindowResolution(new setWindowResolution(ev.name, ev.title)); 
        } else {

        }
    }







    void processFrame () {

    }    
};


















