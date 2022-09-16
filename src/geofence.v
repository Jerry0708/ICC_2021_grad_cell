module geofence ( clk,reset,X,Y,R,valid,is_inside);
input clk;
input reset;
input [9:0] X;
input [9:0] Y;
input [10:0] R;
output reg valid;
output reg is_inside;

//---def fsm reg---
reg [4:0]cur_state;
reg [4:0]next_state;

//---def reg---
integer i;
reg [9:0]x[0:5];
reg [9:0]y[0:5];
reg [17:0]r[0:5];		
reg [2:0]count;
reg signed[21:0]cross_vector;
reg [1:0]pos;
reg [2:0]fix;
reg [17:0]s;		
reg signed[34:0]temp;	
reg signed[34:0]area;
reg [35:0]delta_area;
reg signed[17:0]neg_a;
reg signed[17:0]neg_b;
wire [17:0]root;	

reg signed[17:0]mul_in1;
reg signed[17:0]mul_in2;
wire [34:0]multiplier;

reg [4:0]fsm_cnt;

assign multiplier = mul_in1 * mul_in2;

//---sqrt---
DW_sqrt sqrt(
	.a(temp),
	.root(root)
);

//---FSM---
always@(posedge clk or posedge reset) begin
	if(reset)	cur_state <= 0;
	else 		cur_state <= next_state;
end

//---fsm adder control---
always@(posedge clk or posedge reset) begin
	if(reset)	fsm_cnt <= 0;
	else begin
		case(cur_state)
			1:
			begin
				if(fix== 4 && pos==1)	fsm_cnt <= 6;			
				else 					fsm_cnt <= 3;			
			end
			21: 
			begin
				if(count==5) fsm_cnt <= 23;
				else 		 fsm_cnt <= 6;
			end
			24: //計算多邊形位置
			begin
				if(count==5) fsm_cnt <= 26;
				else 		 fsm_cnt <= 23;
			end
			default : fsm_cnt <= fsm_cnt + 1;
		endcase
	end
end

//---state transfer
always@(*) begin
	case(cur_state)
		0:	//read data
		begin
			if(count==6) next_state = 1;
			else 	     next_state = 0;
		end
		1:
		begin
			if(fix== 4 && pos==1)	next_state = 5;			
			else 					next_state = 2;			
		end
		2,3:
		begin
			next_state = fsm_cnt;
		end
		4:
		begin
			next_state = 1;
		end
		5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20:	//計算obect位置
		begin
			next_state = fsm_cnt;
		end
		21: 
		begin
			if(count==5) next_state = 22;
			else 		 next_state = 5;
		end
		22,23:
		begin
			next_state = fsm_cnt;
		end
		24: //計算多邊形位置
		begin
			if(count==5) next_state = 25;
			else 		 next_state = 22;
		end
		25,26://compare
		begin
			next_state = fsm_cnt;
		end
		27:
		begin
			next_state = 0;
		end
		default:
		begin
			next_state = 0;
		end
	endcase
end


//---read X Y R
always@(posedge clk or posedge reset)begin
	if(reset) begin 
		count <= 0;
		cross_vector <= 22'd0;
		pos <= 2'd0;
		fix <= 3'd1;
		s <= 18'd0;
		temp <= 35'd0;
		area <= 35'd0;
		delta_area <= 36'd0;
		neg_a <= 18'd0; 
		neg_b <= 18'd0;
		valid <= 0;
		is_inside <= 0;
		mul_in1 <= 18'd0;
		mul_in2 <= 18'd0;
		
		for(i=0; i<=3'd5; i=i+1) begin
			x[i] <= 10'd0;
			y[i] <= 10'd0;
			r[i] <= 18'd0;
		end
		
	end
	else begin
		case(cur_state)
			0:
			begin
				valid <= 0;
				if(count==6) begin
					count <= 0;
					for(i=0; i<=3'd5; i=i+1) begin	//6 bit fix point
						r[i] <= r[i] << 6;
					end
				end
				else begin
					count <= count + 1'b1; 
					x[count] <= X;
					y[count] <= Y;
					r[count] <= {7'd0,R};
				end
			end
			1:
			begin
				mul_in1 <= x[fix] - x[0];
				mul_in2 <= y[fix+pos+1] - y[0];
			end
			2:
			begin
				cross_vector <= multiplier[21:0];
				mul_in1 <= x[fix+pos+1] - x[0];
				mul_in2 <= y[fix] - y[0];
			end
			3:
			begin
				cross_vector <= cross_vector - multiplier[21:0];
			end
			4:
			begin
				if(fix==1 && pos==3) begin	
					fix <= fix + 1;
					pos <= 0;
				end
				else if(fix==2 && pos==2) begin	
					fix <= fix + 1;
					pos <= 0;
				end
				else if(fix==3 && pos==1) begin
					fix <= fix + 1;
					pos <= 0;
				end
				else 
					pos <= pos + 1;
					
				if(!cross_vector[21]) begin
					x[fix] <= x[fix+pos+1];
					y[fix] <= y[fix+pos+1];
					r[fix] <= r[fix+pos+1];
					x[fix+pos+1] <= x[fix];
					y[fix+pos+1] <= y[fix];
					r[fix+pos+1] <= r[fix];
				end
			end
			5:
			begin	//算邊長
				fix <= 1;	pos <= 0;
				if(count==5) begin
					neg_a <= x[0] - x[count];
					neg_b <= y[0] - y[count];
				end
				else begin
					neg_a <= x[count+1] - x[count];
					neg_b <= y[count+1] - y[count];
				end
			end
			6:
			begin
				if(neg_a < 0) neg_a <= ~neg_a + 1;
				if(neg_b < 0) neg_b <= ~neg_b + 1;
			end
			7:
			begin
				mul_in1 <= neg_a;
				mul_in2 <= neg_a;
			end
			8:
			begin
				temp <= multiplier;
				mul_in1 <= neg_b;
				mul_in2 <= neg_b;
			end
			9:
			begin
				temp <= (temp + multiplier) << 12;
			end
			10:
			begin
				if(count==5)
					s <= (r[count] + r[0] + root)>>1;
				else 
					s <= (r[count] + r[count+1] + root)>>1;
			end
			11:		//算更號
			begin
				if(count==5) begin
					neg_a <= s-r[0];
					neg_b <= s-root;
				end
				else begin
					neg_a <= s-r[count+1];
					neg_b <= s-root;
				end
			end
			12:
			begin	//有加入定點數
				if(neg_a < 0)	neg_a <= (~neg_a) | {12'd0,1'b1,5'd0}; 
				if(neg_b < 0)	neg_b <= (~neg_b) | {12'd0,1'b1,5'd0};
			end
			13:
			begin
				mul_in1 <= neg_a;
				mul_in2 <= neg_b;
			end
			14:
			begin
				temp <= multiplier;
			end
			15:
			begin
				area <= root;	//4bit fix point
				neg_a <= s;
				neg_b <= s-r[count];
			end
			16:
			begin
				if(neg_b < 0)	neg_b <= (~neg_b) | {12'd0,1'b1,5'd0};
			end
			17:
			begin
				mul_in1 <= neg_a;
				mul_in2 <= neg_b;
			end
			18:
			begin
				temp <= multiplier;
			end
			19:
			begin
				mul_in1 <= root;
				mul_in2 <= area[17:0];
			end
			20:
			begin
				area <= multiplier;	//8bit fix point
			end
			21:
			begin
				area <= 0;
				delta_area <= delta_area + area;
				if(count==5)
					count <= 0;
				else 
					count <= count + 1;
			end
			22:
			begin
				if(count==5) begin
					mul_in1 <= x[count];
					mul_in2 <= y[0];
				end
				else begin
					mul_in1 <= x[count];
					mul_in2 <= y[count+1];
				end
			end
			23:
			begin
				area <= area + multiplier;
				if(count==5) begin
					mul_in1 <= x[0];
					mul_in2 <= y[count];
				end
				else begin
					mul_in1 <= x[count+1];
					mul_in2 <= y[count];
				end
			end
			24:
			begin	
				area <= area - multiplier;
				if(count==5) count <= 0;
				else 		 count <= count + 1;	
			end
			25:
			begin
				if(area < 0)
					area <= (~area + 1) >> 1;
				else 
					area <= area >> 1;
				delta_area <= delta_area >> 12;
			end
			26:
			begin
				valid <= 1; 
				if(delta_area > area )	is_inside <= 0;
				else 					is_inside <= 1;
			end
			27: begin area <= 0; valid <= 0;end
		endcase
	end
end
endmodule

