import java.awt.event.*;

import java.io.*;
import java.net.*;

import javax.swing.*;

import com.biotools.meerkat.*;
import com.biotools.meerkat.Action;
import com.biotools.meerkat.util.Preferences; 

import org.json.simple.JSONObject;


/** 
 * A simple Meerkat <=> ACPC bridge
 * 
 * @author mike@mikec.me
 */
public class TcpBot implements Player {
   private static final String ALWAYS_CALL_MODE = "ALWAYS_CALL_MODE";

   private int ourSeat;       // our seat for the current hand
   private Card c1, c2;       // our hole cards
   private GameInfo gi;       // general game information
   private Preferences prefs; // the configuration options for this bot
	 private String actions;
	 private String lastMatchState;
	 private boolean hasGotHoleCards;

	 private boolean hasOpenedTable = false;
	 ServerSocket welcomeSocket;
	 BufferedReader inFromClient;
	 DataOutputStream outToClient;
      
   public TcpBot() { }  
   
   /**
    * An event called to tell us our hole cards and seat number
    * @param c1 your first hole card
    * @param c2 your second hole card
    * @param seat your seat number at the table
    */
   public void holeCards(Card c1, Card c2, int seat) {
      this.c1 = c1;
      this.c2 = c2;
      this.ourSeat = seat;
			this.hasGotHoleCards = true;
   }

	 public int getNumPlayers() {
		 int seat = 0;
		 PlayerInfo p;
		 int nPlayers = 0;
		 while (seat < gi.getNumSeats()) {
			 p = gi.getPlayer(seat);
			 if (p != null) {
				 nPlayers++;
			 }
			 seat++;
		 }
		 return nPlayers;
	 }

	 public int getPosition() {
	    int ourPos = 0;
			int nextSeat = gi.nextPlayer(gi.getButtonSeat());
			while (nextSeat != ourSeat && ourPos < 10) {
				nextSeat = gi.nextPlayer(nextSeat);
				ourPos++;
			}
			return ourPos;
	 }

	 public long getHandNumber() {
		 return gi.getGameID();
	 }

	 public String getStacks() {
		 int seat = 0;
		 int npl = getNumPlayers();
		 int i = 0;
		 String stacks = "";
		 while (seat < 10) {
			 PlayerInfo pi = gi.getPlayer(seat);
			 if (pi != null) {
				 stacks += Double.toString(pi.getBankRoll());
				 i++;
				 if (i != npl) {
					 stacks += ",";
				 }
			 }
			 seat++;
		 }
		 return stacks;
	 }

	 public String getNames() {
		 int seat = 0;
		 int npl = getNumPlayers();
		 int i = 0;
		 String names = "";
		 while (seat < 10) {
			 PlayerInfo pi = gi.getPlayer(seat);
			 if (pi != null) {
				 names += pi.getName();
				 i++;
				 if (i != npl) {
					 names += ",";
				 }
			 }
			 seat++;
		 }
		 return names;
	 }

	 public String getInitialState() throws IOException {
		 String out = "INITIAL_STATE:";
		 out = out + Integer.toString(getNumPlayers()) + "," + Double.toString(gi.getSmallBlindSize()) + "," + Double.toString(gi.getBigBlindSize()) + "," + Integer.toString(gi.getButtonSeat()) + "," + getStacks() + "," + getNames();
		 return out;

		 /*
		 obj.writeJSONString(out);
		 String jsonText = out.toString();
		 
		 return jsonText;
		 */
	 }

	 public String getMatchState() {
		 String ms = "MATCHSTATE:" + Integer.toString(getPosition()) + ":" + getHandNumber() + ":" + getBettingRounds() + ":" + getHoleCardsAndBoardCards();
		 return ms;
	 }

	 public String getBettingRounds() {
		 return actions; 
	 }

	 public String getBoardString() {
		 Hand board = gi.getBoard();
		 String bs = board.toString();
		 bs = bs.replaceAll("\\s", "");
		 switch(board.size()) {
			 case 0:
				 return "";
			 case 3:
				 return "/" + bs;
			 case 4:
				 return "/" + bs.substring(0,6) + "/" + bs.substring(6,8);
			 case 5:
				 return "/" + bs.substring(0,6) + "/" + bs.substring(6,8) + "/" + bs.substring(8,10);
		 }
		 return "";
	 }

	 public String getHoleCardsAndBoardCards() {
		 String hc = "";
		 String[] hands;
		 int i = gi.nextPlayer(gi.getButtonSeat()); // start at first from dealear
		 int lastpos = i;
		 do {
			 if (gi.inGame(i)) { // if a player is in seat i
					if (i == ourSeat) {
						hc = hc + c1.toString() + c2.toString() + "|";
					}
					else {
						PlayerInfo player = gi.getPlayer(i);
						Hand ph = player.getRevealedHand();
						if (ph != null) {
							hc = hc + ph.toString();
						}
						hc = hc + "|";
					}
			 }
			 i = gi.nextPlayer(i);
      }
			while (!(i == lastpos));
			hc = hc.substring(0,hc.length() - 1);
			hc = hc.replaceAll("\\s", "");

			String bc = getBoardString(); 

			return hc + bc;
	 }

	 private void writeClient(String msg) {
		 try {
				outToClient.writeBytes(msg + "\r\n");
		 } catch (IOException e) {
			 debug("Failed to write to client");
		 }
	 }

	 private void printMatchState() {

		 String newms = getMatchState();
		 if (!(newms.equals(lastMatchState))) {
			writeClient(getMatchState());
			lastMatchState = newms;
		 }
	 }

	 public Action getActionFromClient() {
		 String msg = "";
		 try { 
			msg = inFromClient.readLine();
		 }
		 catch(IOException e) {
		 }
		 int msgl = msg.length();
		 char move = msg.charAt(msg.length() - 1);
		 switch (move) {
			 case 'r':
				 return Action.raiseAction(gi);
			 case 'c':
				 return Action.callAction(gi);
			 default:
				 return Action.checkOrFoldAction(gi);
		 }
	 }

   /**
    * Requests an Action from the player
    * Called when it is the Player's turn to act.
    */
   public Action getAction() {
			printMatchState();
			return getActionFromClient();
   }
   
   /**
    * If you implement the getSettingsPanel() method, your bot will display
    * the panel in the Opponent Settings Dialog.
    * @return a GUI for configuring your bot (optional)
    */
   public JPanel getSettingsPanel() {
      JPanel jp = new JPanel();
      final JCheckBox acMode = new JCheckBox(
            "Always Call Mode", prefs.getBooleanPreference(ALWAYS_CALL_MODE));
      acMode.addItemListener(new ItemListener() {
         public void itemStateChanged(ItemEvent e) {
            prefs.setPreference(ALWAYS_CALL_MODE, acMode.isSelected());
         }        
      });
      jp.add(acMode);
      return jp;
   }
   

   /**
    * Get the current settings for this bot.
    */
   public Preferences getPreferences() {
      return prefs;
   }

   /**
    * Load the current settings for this bot.
    */
   public void init(Preferences playerPrefs) {
      this.prefs = playerPrefs;
   }

   /**
    * An example setting for this bot. It can be turned into
    * an always-call mode, or to a simple strategy.
    * @return true if always-call mode is active.
    */ 
   public boolean getAlwaysCallMode() {
      return prefs.getBooleanPreference(ALWAYS_CALL_MODE, false);
   }

   /**
    * @return true if debug mode is on.
    */
   public boolean getDebug() {
		 return true;
   }
   
   /**
    * print a debug statement.
    */
   public void debug(String str) {
      if (getDebug()) {
				try {
				 File file = new File("C:\\poker\\test.log");
			// if file doesnt exists, then create it
			if (!file.exists()) {
				file.createNewFile();
			}
 
			FileWriter fw = new FileWriter(file.getAbsoluteFile(), true);
			BufferedWriter bw = new BufferedWriter(fw);
			bw.write(str + "\n");
			bw.close();
      
			} catch (IOException e) {
			}
   }
	 }
   
   /**
    * A new betting round has started.
    */ 
   public void stageEvent(int stage) {
		 if (stage != Holdem.PREFLOP) {
			actions += "/" ;
		 }
	 }

   /**
    * A showdown has occurred.
    * @param pos the position of the player showing
    * @param c1 the first hole card shown
    * @param c2 the second hole card shown
    */
   public void showdownEvent(int seat, Card c1, Card c2) {}

   /**
    * A new game has been started.
    * @param gi the game stat information
    */
   public void gameStartEvent(GameInfo gInfo) {
      this.gi = gInfo;
			actions = "";
			try {
			if (hasOpenedTable == false) {
				debug("Waiting for bot...");
				welcomeSocket = new ServerSocket(27700,0,null);
				Socket connectionSocket = welcomeSocket.accept();
				inFromClient = new BufferedReader(new InputStreamReader(connectionSocket.getInputStream()));
        outToClient = new DataOutputStream(connectionSocket.getOutputStream());
				writeClient(getInitialState());
			}
			} catch (Exception e) {
				debug("Something went wrong");
			}
   }
   
   /**
    * An event sent when all players are being dealt their hole cards
    */
   public void dealHoleCardsEvent() {}   

   /**
    * An action has been observed. 
    */
   public void actionEvent(int pos, Action act) {
		 if (act.isBet() || act.isRaise()) {
		   actions += "r";
		 }
		 else if(act.isFold()) {
			 actions += "f";
		 }
		 else if(act.isCall() || act.isCheck()) {
			 actions += "c";
		 }
		 else {
			 return;
		 }
		 return;
	 }
   
   /**
    * The game info state has been updated
    * Called after an action event has been fully processed
    */
   public void gameStateChanged() {
		 if (hasGotHoleCards) {
			printMatchState();
		 }
	 }

	 public void stageEvent() {
		 if (hasGotHoleCards) {
			printMatchState();
		 }
	 }

   /**
    * The hand is now over. 
    */
   public void gameOverEvent() {
		 printMatchState();
	   writeClient("#END_HAND");
		 hasGotHoleCards = false;
	 }

   /**
    * A player at pos has won amount with the hand handName
    */
   public void winEvent(int pos, double amount, String handName) {}
}
